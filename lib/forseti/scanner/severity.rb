# frozen_string_literal: true

module Forseti
  module Scanner
    # The shared severity vocabulary, ordered least to most severe.
    module Severity
      LEVELS = %i[info low medium high critical].freeze

      # Score penalty weights (ADR 001 §7; formula versioned with defaults).
      WEIGHTS = { info: 0, low: 1, medium: 3, high: 6, critical: 10 }.freeze

      class << self
        # @param severity [Symbol]
        # @return [Symbol]
        # @raise [ArgumentError] for unknown severities
        def validate!(severity)
          return severity if LEVELS.include?(severity)

          raise ArgumentError, "Unknown severity #{severity.inspect}. Levels: #{LEVELS.join(', ')}"
        end

        # Whether +severity+ is at least as severe as +threshold+.
        #
        # @param severity [Symbol]
        # @param threshold [Symbol]
        def at_least?(severity, threshold)
          LEVELS.index(validate!(severity)) >= LEVELS.index(validate!(threshold))
        end

        # @param severity [Symbol]
        # @return [Integer] the score penalty weight
        def weight(severity)
          WEIGHTS.fetch(validate!(severity))
        end
      end
    end
  end
end
