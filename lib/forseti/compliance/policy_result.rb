# frozen_string_literal: true

require "time"

module Forseti
  module Compliance
    # The outcome of evaluating one policy. {#to_h} is the JSON contract —
    # and always carries the disclaimer (ADR 005 §7).
    class PolicyResult
      attr_reader :policy, :requirement_results

      def initialize(policy, requirement_results)
        @policy = policy
        @requirement_results = requirement_results
      end

      def met = requirement_results.select(&:met?)
      def unmet = requirement_results.select(&:unmet?)
      def unverified = requirement_results.select(&:unverified?)

      # met / (met + unmet) × 100. Unverified requirements are excluded from
      # the denominator (D10) — nil when nothing could be assessed at all.
      #
      # @return [Integer, nil]
      def score
        assessed = met.size + unmet.size
        return nil if assessed.zero?

        (met.size * 100.0 / assessed).round
      end

      def to_h
        {
          policy: policy.key,
          name: policy.name,
          version: policy.version,
          generated_at: Time.now.utc.iso8601,
          score: score,
          summary: { met: met.size, unmet: unmet.size, unverified: unverified.size,
                     attested: requirement_results.count(&:attested?) },
          requirements: requirement_results.map(&:to_h),
          disclaimer: DISCLAIMER
        }
      end
    end
  end
end
