# frozen_string_literal: true

require "yaml"
require "date"

module Forseti
  module Compliance
    # Human attestations for requirements that cannot be machine-verified.
    # Stored in a YAML file (config/forseti/attestations.yml by default) so
    # they live in git and get reviewed like code (ADR 005 §5).
    class Attestations
      # One attestation record. Valid means: someone (attested_by) said so on
      # a date (attested_on), and it hasn't expired.
      Attestation = Struct.new(:attested_by, :attested_on, :note, :expires_on, keyword_init: true) do
        def valid?
          return false if attested_by.to_s.strip.empty? || attested_on.nil?

          expires_on.nil? || expires_on >= Date.current
        end

        def expired?
          !expires_on.nil? && expires_on < Date.current
        end

        def to_h
          super.compact
        end
      end

      # @param path [String, Pathname, nil] resolved against Rails.root when relative
      # @return [Forseti::Compliance::Attestations]
      def self.load(path = nil)
        path ||= Forseti.config.compliance.attestations_path
        full_path = Pathname.new(path)
        full_path = Rails.root.join(full_path) if defined?(Rails.root) && Rails.root && full_path.relative?
        return new({}) unless full_path.exist?

        data = YAML.safe_load(full_path.read, permitted_classes: [Date]) || {}
        new(data)
      end

      def initialize(data)
        @data = data
      end

      # @return [Attestation, nil]
      def for(policy_key, requirement_key)
        entry = @data.dig(policy_key.to_s, requirement_key.to_s)
        return nil unless entry.is_a?(Hash)

        Attestation.new(
          attested_by: entry["attested_by"],
          attested_on: entry["attested_on"],
          note: entry["note"],
          expires_on: entry["expires_on"]
        )
      end
    end
  end
end
