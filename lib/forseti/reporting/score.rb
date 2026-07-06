# frozen_string_literal: true

module Forseti
  module Reporting
    # The transparent scoring formula (ADR 000 D10, ADR 001 §7):
    #
    #   score = 100 × (1 − Σ weight(failed) / Σ weight(passed + failed))
    #
    # Skipped and errored checks are excluded from the denominator, so an app
    # is never graded on checks that couldn't run. An app with nothing to
    # score gets 100 — no evidence of problems, stated as such by the grade
    # alongside the check counts.
    class Score
      GRADES = { 90 => "A", 80 => "B", 70 => "C", 60 => "D" }.freeze

      # @param results [Array<Forseti::Scanner::Result>]
      def initialize(results)
        @scoreable = results.select(&:scoreable?)
      end

      # @return [Integer] 0..100
      def value
        return 100 if max_penalty.zero?

        (100 * (1 - (penalty.to_f / max_penalty))).round
      end

      # @return [String] A/B/C/D/F
      def grade
        GRADES.find { |floor, _| value >= floor }&.last || "F"
      end

      # @return [Hash{String => Integer}] score per check category
      def by_category
        @scoreable.group_by(&:category).transform_values do |results|
          self.class.new(results).value
        end
      end

      def to_h
        { value: value, grade: grade, by_category: by_category }
      end

      private

      def penalty
        @scoreable.select(&:failed?).sum { |result| Scanner::Severity.weight(result.severity) }
      end

      def max_penalty
        @scoreable.sum { |result| Scanner::Severity.weight(result.severity) }
      end
    end
  end
end
