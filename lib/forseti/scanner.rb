# frozen_string_literal: true

module Forseti
  # Configuration-posture scanning (ADR 001).
  #
  # The scanner inspects the *booted* application — the effective runtime
  # configuration after all initializers ran — and produces a
  # {Forseti::Reporting::Report}. It is Observe-tier (ADR 000, D2): read-only,
  # with zero request-path footprint.
  module Scanner
    class << self
      # The global check registry, pre-populated with the built-in checks.
      #
      # @return [Forseti::Scanner::Registry]
      def registry
        @registry ||= Registry.new(built_in_checks)
      end

      # Registers an application- or gem-provided check.
      #
      # @param check_class [Class] a {Forseti::Scanner::Check} subclass
      # @return [void]
      delegate :register, to: :registry

      # Runs every registered check and returns the report.
      #
      # @param context [Forseti::Scanner::Context]
      # @return [Forseti::Reporting::Report]
      def run(context: Context.new)
        results = Runner.new(registry.checks, context: context, config: Forseti.config.scanner).run
        Reporting::Report.new(results, context: context)
      end

      # Discards the registry. Intended for test suites.
      #
      # @return [void]
      def reset_registry!
        @registry = nil
      end

      private

      def built_in_checks # rubocop:disable Metrics/MethodLength -- a plain list
        [
          Checks::AuditStorage,
          Checks::ConsentStorage,
          Checks::LoadDefaults,
          Checks::ForceSsl,
          Checks::HSTS,
          Checks::HostAuthorization,
          Checks::Cookies,
          Checks::CSP,
          Checks::CSPNonce,
          Checks::DefaultHeaders,
          Checks::Csrf,
          Checks::OpenRedirects,
          Checks::MasterKey,
          Checks::FilterParameters,
          Checks::LogLevel
        ]
      end
    end
  end
end
