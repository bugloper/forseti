# frozen_string_literal: true

module Forseti
  # The shared PII registry (ADR 000 D9, ADR 003): one place that defines what
  # counts as sensitive. Parameter filtering, log redaction, scanner probes,
  # and (later) compliance classification all read from here — teach Forseti
  # about a domain-specific identifier once and every layer knows:
  #
  #   Forseti::PII.register(:employee_badge,
  #                         sensitivity: :medium,
  #                         key_patterns: [/badge (number|id)/],
  #                         filter_keys: %i[badge_number])
  module PII
    class << self
      # @return [Forseti::PII::Registry]
      def registry
        @registry ||= Registry.new(Builtins.all)
      end

      # Registers an application-defined PII type. See {Forseti::PII::Type}
      # for the options.
      #
      # @param key [Symbol]
      # @return [Forseti::PII::Type]
      def register(key, **)
        registry.register(Type.new(key: key, **))
      end

      # @param key [Symbol]
      # @return [Forseti::PII::Type, nil]
      delegate :[], to: :registry

      delegate :types, :detect_key, :detect_value, :filter_keys, :probe_keys, to: :registry

      # Discards the registry (custom registrations included). For test suites.
      #
      # @return [void]
      def reset_registry!
        @registry = nil
      end
    end
  end
end
