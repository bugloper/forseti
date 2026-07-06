# frozen_string_literal: true

module Forseti
  module PII
    # Holds PII types keyed by category. App-extensible, like the scanner's
    # check registry (ADR 000, D7/D9).
    class Registry
      # @param initial [Array<Forseti::PII::Type>]
      def initialize(initial = [])
        @types = {}
        initial.each { |type| register(type) }
      end

      # @param type [Forseti::PII::Type]
      # @return [Forseti::PII::Type]
      # @raise [Forseti::Error] on duplicate keys
      def register(type)
        raise Error, "A PII type #{type.key.inspect} is already registered" if @types.key?(type.key)

        @types[type.key] = type
      end

      # @param key [Symbol]
      # @return [Forseti::PII::Type, nil]
      def unregister(key)
        @types.delete(key.to_sym)
      end

      def [](key)
        @types[key.to_sym]
      end

      # @return [Array<Forseti::PII::Type>]
      def types
        @types.values
      end

      # Types whose key patterns match the given attribute/parameter name.
      #
      # @param name [String, Symbol]
      # @return [Array<Forseti::PII::Type>]
      def detect_key(name)
        normalized = normalize_key(name)
        types.select { |type| type.matches_key?(normalized) }
      end

      # Types whose value pattern (and validator) match the given value.
      #
      # @param value [Object] non-strings never match
      # @return [Array<Forseti::PII::Type>]
      def detect_value(value)
        return [] unless value.is_a?(String)

        types.select { |type| type.matches_value?(value) }
      end

      # @return [Array<Symbol>] union of every type's recommended filter keys
      def filter_keys
        types.flat_map(&:filter_keys).uniq
      end

      # @return [Array<String>] parameter names the scanner probes
      def probe_keys
        types.flat_map(&:probes).uniq
      end

      # Lowercases and collapses separators so patterns can use word
      # boundaries: "User_SSN" => "user ssn" (a bare \b fails on snake_case —
      # underscore is a word character).
      #
      # @param name [String, Symbol]
      # @return [String]
      def normalize_key(name)
        name.to_s.downcase.gsub(/[^a-z0-9]+/, " ").strip
      end
    end
  end
end
