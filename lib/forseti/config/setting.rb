# frozen_string_literal: true

module Forseti
  module Config
    # A single declared setting: its metadata, default, and validation rules.
    # Instances are created by {Forseti::Config::Base.setting} and are
    # introspectable so the Scanner and documentation can enumerate them.
    class Setting
      attr_reader :name, :values, :type, :description

      def initialize(name:, default:, values: nil, type: nil, description: nil)
        @name = name
        @default = default
        @values = values&.freeze
        @type = type
        @description = description
      end

      # Resolves this setting's default under the given defaults version.
      # Mutable defaults are duped so a caller can't corrupt the shared
      # declaration (assignment, not mutation, is the configuration API).
      #
      # @param defaults_version [String]
      # @return [Object]
      def default_for(defaults_version)
        value = @default.is_a?(VersionedDefault) ? @default.resolve(defaults_version) : @default
        value.is_a?(Array) || value.is_a?(Hash) ? value.dup : value
      end

      # @param value [Object]
      # @return [Object] the value, if valid
      # @raise [Forseti::InvalidSettingError]
      def validate!(value)
        validate_allowed_values!(value)
        validate_boolean!(value)
        value
      end

      private

      def validate_allowed_values!(value)
        return unless values&.exclude?(value)

        raise InvalidSettingError,
              "`#{name}` must be one of #{values.map(&:inspect).join(', ')}, got #{value.inspect}"
      end

      def validate_boolean!(value)
        return unless type == :boolean && [true, false].exclude?(value)

        raise InvalidSettingError, "`#{name}` must be true or false, got #{value.inspect}"
      end
    end
  end
end
