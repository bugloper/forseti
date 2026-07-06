# frozen_string_literal: true

module Forseti
  module Scanner
    # Runs checks against a context, deciding applicability and isolating
    # failures: a crashing check becomes an :error result and can never take
    # down the run or hide other findings (ADR 001 §7).
    class Runner
      PRODUCTION_ONLY_REASON =
        "Only meaningful in production-like environments — run with RAILS_ENV=production for full coverage"

      # @param checks [Array<Class>]
      # @param context [Forseti::Scanner::Context]
      # @param config [Forseti::Scanner::Config]
      def initialize(checks, context:, config: Forseti.config.scanner)
        @checks = checks
        @context = context
        @config = config
      end

      # @return [Array<Forseti::Scanner::Result>] one result per check
      def run
        @checks.map { |check_class| run_check(check_class) }
      end

      private

      attr_reader :context, :config

      def run_check(check_class)
        if skipped_by_config?(check_class)
          return Result.skipped(check_class, "Skipped by scanner.skip_checks", cause: :config)
        end

        if check_class.production_only? && !context.production_like?
          return Result.skipped(check_class, PRODUCTION_ONLY_REASON, cause: :environment)
        end

        check = check_class.new(context)
        return Result.skipped(check_class, check.not_applicable_reason, cause: :not_applicable) unless check.applies?

        check.call
      rescue StandardError => e
        Result.errored(check_class, e)
      end

      def skipped_by_config?(check_class)
        config.skip_checks.map(&:to_s).include?(check_class.id)
      end
    end
  end
end
