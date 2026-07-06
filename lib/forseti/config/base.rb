# frozen_string_literal: true

module Forseti
  module Config
    # Base class for module configuration objects (ADR 000, D5).
    #
    # Subclasses declare their settings explicitly, which buys three things
    # over an OpenStruct-style bag: typos raise with the valid alternatives
    # listed, values are validated on assignment, and every setting is
    # introspectable — which is what lets the Scanner audit Forseti's own
    # configuration.
    #
    #   class Security::Config < Forseti::Config::Base
    #     setting :mode,
    #             default: versioned("1.0" => :report),
    #             values: MODES,
    #             description: "How violations are handled."
    #   end
    #
    # Defaults wrapped in {.versioned} resolve against the root
    # configuration's pinned defaults version (ADR 000, D4).
    class Base
      # Enforcement modes shared by all enforcing features (ADR 000, D3).
      MODES = %i[off report enforce].freeze

      class << self
        # Settings declared on this class, keyed by name. Inherited settings
        # are included.
        #
        # @return [Hash{Symbol => Forseti::Config::Setting}]
        def settings
          @settings ||= {}
        end

        # Declares a setting with a reader, a validating writer, and — for
        # booleans — a predicate.
        #
        # @param name [Symbol]
        # @param default [Object, Forseti::Config::VersionedDefault]
        # @param values [Array, nil] allowed values, validated on assignment
        # @param type [Symbol, nil] +:boolean+ adds a `name?` predicate and
        #   restricts values to true/false
        # @param description [String, nil] shown in errors, docs, and reports
        # @return [void]
        def setting(name, default:, values: nil, type: nil, description: nil)
          name = name.to_sym
          settings[name] = Setting.new(
            name: name, default: default, values: values, type: type, description: description
          )

          define_method(name) { read_setting(name) }
          define_method(:"#{name}=") { |value| write_setting(name, value) }
          define_method(:"#{name}?") { !!read_setting(name) } if type == :boolean
        end

        # Wraps per-defaults-version default values:
        #
        #   versioned("1.0" => :report, "1.1" => :enforce)
        #
        # @param map [Hash{String => Object}]
        # @return [Forseti::Config::VersionedDefault]
        def versioned(map)
          VersionedDefault.new(map)
        end

        private

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@settings, settings.dup)
        end
      end

      setting :enabled,
              default: versioned("1.0" => false),
              type: :boolean,
              description: "Whether this module is active at all."

      # @param root [Forseti::Configuration] the root configuration this module
      #   configuration resolves its defaults version against
      def initialize(root = Forseti.config)
        @root = root
        @values = {}
      end

      # Opts into the module with its recommended (secure) defaults. Individual
      # settings can still be dialed back afterwards.
      #
      # @return [self]
      def enable!
        self.enabled = true
        apply_recommended_defaults!
        self
      end

      # Turns the module off entirely.
      #
      # @return [self]
      def disable!
        self.enabled = false
        self
      end

      # Re-validates every explicitly assigned value. Assignment already
      # validates; subclasses override this for cross-setting rules.
      #
      # @return [true]
      # @raise [Forseti::InvalidSettingError]
      def validate!
        @values.each { |name, value| self.class.settings.fetch(name).validate!(value) }
        true
      end

      private

      attr_reader :root

      # Hook for subclasses: apply opinionated enforcing defaults when the
      # user opts in via {#enable!}.
      def apply_recommended_defaults!; end

      def read_setting(name)
        @values.fetch(name) { self.class.settings.fetch(name).default_for(root.defaults) }
      end

      def write_setting(name, value)
        self.class.settings.fetch(name).validate!(value)
        @values[name] = value
      end

      def method_missing(name, *)
        setting_name = name.to_s.delete_suffix("=")
        raise UnknownSettingError,
              "Unknown setting `#{setting_name}` for #{self.class.name}. " \
              "Available settings: #{self.class.settings.keys.sort.join(', ')}"
      end

      def respond_to_missing?(name, include_private = false)
        super
      end
    end
  end
end
