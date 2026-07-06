# frozen_string_literal: true

module Forseti
  # The compliance policy engine (ADR 000 D8, ADR 005).
  #
  # A policy is a versioned set of requirements mapped to legal controls.
  # Checkable requirements are machine-verified against the live app (via
  # scanner checks and verify procs); attestable ones are only ever satisfied
  # by an explicit human attestation with author and date — and reports always
  # distinguish the two.
  #
  # Forseti provides technical evidence and checklists, not legal advice. A
  # passing report does not constitute or guarantee regulatory compliance.
  module Compliance
    DISCLAIMER = "Forseti provides technical evidence to support compliance work, not legal " \
                 "advice. A passing report does not constitute or guarantee regulatory compliance."

    class << self
      # @return [Hash{Symbol => Forseti::Compliance::Policy}]
      def registry
        @registry ||= {
          gdpr: Policies::GDPR.policy,
          ccpa: Policies::CCPA.policy,
          lgpd: Policies::LGPD.policy,
          dpdp: Policies::DPDP.policy
        }
      end

      # Defines a custom policy on the same engine — org baselines, customer
      # security addenda, internal standards:
      #
      #   Forseti::Compliance.define_policy(:acme_baseline, name: "ACME Baseline",
      #                                     version: "2026.1") do |p|
      #     p.requirement :sso, title: "Admin behind SSO", article: "SEC-4",
      #                   checks: %w[custom.internal_auth]
      #   end
      #
      # @return [Forseti::Compliance::Policy]
      def define_policy(key, name:, version:, &)
        key = key.to_sym
        raise Error, "A policy #{key.inspect} is already registered" if registry.key?(key)

        registry[key] = Policy.define(key, name: name, version: version, &)
      end

      # @param key [Symbol]
      # @return [Forseti::Compliance::Policy]
      # @raise [Forseti::ConfigurationError] for unknown keys
      def fetch(key)
        registry.fetch(key.to_sym) do
          raise ConfigurationError,
                "Unknown compliance policy #{key.inspect}. Available: #{registry.keys.sort.join(', ')}"
        end
      end

      # Evaluates one policy against the booted application.
      #
      # @return [Forseti::Compliance::PolicyResult]
      def evaluate(key, context: Scanner::Context.new, attestations: Attestations.load)
        Evaluator.new(fetch(key), context: context, attestations: attestations).evaluate
      end

      # Evaluates every policy enabled via config.compliance.enable.
      #
      # @return [Array<Forseti::Compliance::PolicyResult>]
      def evaluate_enabled(context: Scanner::Context.new)
        attestations = Attestations.load
        Forseti.config.compliance.policies.map do |key|
          Evaluator.new(fetch(key), context: context, attestations: attestations).evaluate
        end
      end

      # Discards custom policy registrations. For test suites.
      def reset_registry!
        @registry = nil
      end
    end
  end
end
