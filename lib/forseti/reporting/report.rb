# frozen_string_literal: true

require "time"

module Forseti
  module Reporting
    # The outcome of a scanner run: results, score, and run metadata.
    # {#to_h} is the machine-readable report contract (schema_version 1).
    class Report
      SCHEMA_VERSION = 1

      # @return [Array<Forseti::Scanner::Result>]
      attr_reader :results
      # @return [Forseti::Scanner::Context]
      attr_reader :context

      def initialize(results, context:)
        @results = results
        @context = context
      end

      # @return [Forseti::Reporting::Score]
      def score
        @score ||= Score.new(results)
      end

      def passed = results.select(&:passed?)
      def failed = results.select(&:failed?)
      def skipped = results.select(&:skipped?)
      def errored = results.select(&:errored?)

      # Whether any failure is at least +threshold+ severe. Drives doctor's
      # exit code; +:none+ always returns false.
      #
      # @param threshold [Symbol]
      def failing?(threshold)
        return false if threshold == :none

        failed.any? { |result| Scanner::Severity.at_least?(result.severity, threshold) }
      end

      # @return [Hash] the JSON report
      def to_h
        {
          schema_version: SCHEMA_VERSION,
          generated_at: Time.now.utc.iso8601,
          forseti_version: Forseti::VERSION,
          rails_version: Rails.version,
          ruby_version: RUBY_VERSION,
          environment: context.env,
          score: score.to_h,
          summary: {
            passed: passed.size, failed: failed.size, skipped: skipped.size, errors: errored.size
          },
          results: results.map(&:to_h)
        }
      end
    end
  end
end
