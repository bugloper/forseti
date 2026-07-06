# frozen_string_literal: true

module Forseti
  module Scanner
    # The outcome of running (or deciding not to run) one check.
    class Result
      STATUSES = %i[passed failed skipped error].freeze

      # @return [Class] the check class this result belongs to
      attr_reader :check
      # @return [Symbol] one of {STATUSES}
      attr_reader :status
      # @return [String, nil]
      attr_reader :message
      # @return [Array<String>] itemized findings for multi-part checks
      attr_reader :details
      # @return [Exception, nil] present on :error results
      attr_reader :error
      # @return [Symbol, nil] on :skipped results: :not_applicable (the check
      #   is moot for this app), :environment (couldn't run here — e.g.
      #   production-only in development), or :config (scanner.skip_checks).
      #   Compliance treats :not_applicable as neutral, the others as
      #   unverifiable (ADR 005 §7).
      attr_reader :skip_cause

      def initialize(check:, status:, message: nil, details: [], error: nil, skip_cause: nil)
        unless STATUSES.include?(status)
          raise ArgumentError, "Unknown result status #{status.inspect}. Statuses: #{STATUSES.join(', ')}"
        end

        @check = check
        @status = status
        @message = message
        @details = Array(details)
        @error = error
        @skip_cause = skip_cause
      end

      # Builds an :error result from a check that raised (ADR 001 §7, error
      # isolation).
      def self.errored(check, exception)
        new(check: check, status: :error, message: "Check raised #{exception.class}: #{exception.message}",
            error: exception)
      end

      def self.skipped(check, reason, cause: :not_applicable)
        new(check: check, status: :skipped, message: reason, skip_cause: cause)
      end

      def passed? = status == :passed
      def failed? = status == :failed
      def skipped? = status == :skipped
      def errored? = status == :error

      # Whether this result participates in the score (ADR 001 §7: skipped and
      # errored checks are excluded from the denominator).
      def scoreable? = passed? || failed?

      delegate :id, to: :check
      delegate :severity, to: :check
      delegate :category, to: :check

      # @return [Hash] one entry of the JSON report's +results+ array
      def to_h
        {
          id: id,
          title: check.title,
          category: category,
          severity: severity,
          status: status,
          message: message,
          details: details,
          remediation: failed? ? check.remediation : nil
        }.compact
      end
    end
  end
end
