# frozen_string_literal: true

module Forseti
  module Retention
    # Retention module configuration, available as +Forseti.config.retention+.
    # Policies are declared through {#policy}, which validates immediately.
    class Config < Forseti::Config::Base
      setting :policies,
              default: [],
              description: "Declared retention policies. Use config.retention.policy(...) to add."

      # Declares a retention policy (ADR 006 §6).
      #
      #   config.retention.policy :abandoned_carts,
      #                           model: "Cart", keep_for: 90.days,
      #                           scope: ->(carts) { carts.where(completed_at: nil) }
      #
      # @return [Forseti::Retention::Policy]
      def policy(name, model:, keep_for:, **)
        built = Policy.new(name: name, model: model, keep_for: keep_for, **)
        if policies.any? { |existing| existing.name == built.name }
          raise ConfigurationError, "Retention policy #{built.name.inspect} is declared twice"
        end

        self.policies = policies + [built]
        self.enabled = true
        built
      end
    end
  end
end
