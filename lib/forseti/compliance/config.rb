# frozen_string_literal: true

module Forseti
  module Compliance
    # Compliance module configuration, available as +Forseti.config.compliance+.
    class Config < Forseti::Config::Base
      setting :policies,
              default: [],
              description: "Policy keys to evaluate. Prefer config.compliance.enable :gdpr, " \
                           "which validates the key."

      setting :attestations_path,
              default: "config/forseti/attestations.yml",
              description: "YAML file of human attestations, relative to Rails.root. Generate a " \
                           "skeleton with `rails g forseti:compliance`."

      # The vision API: opt into a policy by key, validated immediately so a
      # typo fails in the initializer, not at report time.
      #
      #   config.compliance.enable :gdpr
      #
      # @param policy_key [Symbol]
      # @return [self]
      def enable(policy_key)
        Compliance.fetch(policy_key) # raises for unknown keys
        self.policies = policies | [policy_key.to_sym]
        self.enabled = true
        self
      end
    end
  end
end
