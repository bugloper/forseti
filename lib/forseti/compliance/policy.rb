# frozen_string_literal: true

module Forseti
  module Compliance
    # A regulation (or internal standard): a versioned, frozen set of
    # requirements. Built through {.define}:
    #
    #   Policy.define(:gdpr, name: "...", version: "2016/679") do |p|
    #     p.requirement :security_of_processing, article: "Art. 32", ...
    #   end
    class Policy
      attr_reader :key, :name, :version, :requirements

      def self.define(key, name:, version:)
        policy = new(key, name: name, version: version)
        yield policy
        policy.finalize!
      end

      def initialize(key, name:, version:)
        @key = key.to_sym
        @name = name
        @version = version
        @requirements = []
      end

      # Declares one requirement. See {Forseti::Compliance::Requirement}.
      def requirement(req_key, **)
        if requirements.any? { |r| r.key == req_key.to_sym }
          raise Error, "Requirement #{req_key.inspect} is declared twice in policy #{key.inspect}"
        end

        requirements << Requirement.new(key: req_key, **)
      end

      # @api private
      def finalize!
        requirements.freeze
        freeze
      end

      def [](req_key)
        requirements.find { |r| r.key == req_key.to_sym }
      end
    end
  end
end
