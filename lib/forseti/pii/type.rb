# frozen_string_literal: true

module Forseti
  module PII
    # One category of personally identifiable information.
    #
    # Detection is two-sided: +key_patterns+ match attribute/parameter/column
    # *names* (against a normalized form — see {Registry#normalize_key}), and
    # +value_pattern+ (+ optional +validator+) matches *values*. Types whose
    # values are arbitrary strings (passwords, tokens) are key-only.
    #
    # Keep custom patterns linear-time (no nested quantifiers) — value
    # patterns run against every log line when redaction is on.
    class Type
      SENSITIVITIES = %i[medium high critical].freeze

      # @return [Symbol]
      attr_reader :key
      # @return [Symbol] :medium, :high, or :critical
      attr_reader :sensitivity
      # @return [Array<Regexp>] matched against normalized key names
      attr_reader :key_patterns
      # @return [Regexp, nil] must not contain capture groups
      attr_reader :value_pattern
      # @return [Array<Symbol>] recommended config.filter_parameters entries
      attr_reader :filter_keys
      # @return [Array<String>] parameter names the scanner probes for coverage
      attr_reader :probes

      def initialize(key:, sensitivity:, key_patterns: [], value_pattern: nil, validator: nil,
                     filter_keys: [], probes: [])
        unless SENSITIVITIES.include?(sensitivity)
          raise ArgumentError, "Unknown sensitivity #{sensitivity.inspect}. Levels: #{SENSITIVITIES.join(', ')}"
        end

        @key = key.to_sym
        @sensitivity = sensitivity
        @key_patterns = Array(key_patterns).freeze
        @value_pattern = value_pattern
        @validator = validator
        @filter_keys = Array(filter_keys).freeze
        @probes = Array(probes).freeze
      end

      # @param normalized_name [String] see {Registry#normalize_key}
      def matches_key?(normalized_name)
        key_patterns.any? { |pattern| pattern.match?(normalized_name) }
      end

      # Whether the string contains at least one validated occurrence.
      #
      # @param string [String]
      def matches_value?(string)
        return false unless value_pattern

        string.to_s.scan(value_pattern).any? { |match| valid_match?(match) }
      end

      # Whether a single +value_pattern+ match survives the validator (Luhn,
      # mod-97, …). Used by the redactor to leave false positives untouched.
      #
      # @param match [String]
      def valid_match?(match)
        @validator.nil? || @validator.call(match)
      end
    end
  end
end
