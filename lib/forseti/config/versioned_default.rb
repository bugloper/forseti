# frozen_string_literal: true

module Forseti
  module Config
    # A default value that varies by pinned defaults version (ADR 000, D4).
    #
    #   VersionedDefault.new("1.0" => :report, "1.1" => :enforce)
    #
    # Resolution picks the value for the newest version that is not newer than
    # the pin — so an app pinned to "1.0" keeps `:report` even after this gem
    # ships a "1.1" entry.
    class VersionedDefault
      # @param map [Hash{String => Object}] defaults version => value
      def initialize(map)
        raise ArgumentError, "VersionedDefault requires at least one version" if map.empty?

        @map = map.to_h { |version, value| [Gem::Version.new(version), value] }.freeze
      end

      # @param defaults_version [String]
      # @return [Object]
      def resolve(defaults_version)
        pin = Gem::Version.new(defaults_version)
        applicable = @map.keys.select { |version| version <= pin }.max

        if applicable.nil?
          raise ConfigurationError,
                "No default declared for defaults version #{defaults_version.inspect} " \
                "(earliest known: #{@map.keys.min})"
        end

        @map[applicable]
      end
    end
  end
end
