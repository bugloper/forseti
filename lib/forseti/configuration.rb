# frozen_string_literal: true

module Forseti
  # The root configuration object returned by {Forseti.config}.
  #
  # It owns two things:
  #
  # 1. The *defaults version* (ADR 000, D4) — a Rails `load_defaults`-style pin.
  #    New Forseti releases may introduce stricter recommended defaults behind a
  #    new version; upgrading the gem never silently changes behavior because
  #    apps stay pinned to the version written in their initializer.
  #
  # 2. The registry of *module configurations* (ADR 000, D5). Each Forseti
  #    module registers its configuration class here, which defines an accessor
  #    on the root:
  #
  #      Forseti::Configuration.register_module(:security, Security::Config)
  #      Forseti.config.security # => Security::Config instance
  class Configuration
    # Every defaults version this release of Forseti understands, oldest first.
    KNOWN_DEFAULTS_VERSIONS = %w[1.0].freeze

    class << self
      # Module configurations registered on this class, keyed by accessor name.
      #
      # @return [Hash{Symbol => Class}]
      def registered_modules
        @registered_modules ||= {}
      end

      # Registers a module configuration class and defines its accessor.
      #
      # @param name [Symbol] accessor name, e.g. +:security+
      # @param config_class [Class, String] a {Forseti::Config::Base} subclass,
      #   or its constant name for lazy loading
      # @return [void]
      def register_module(name, config_class)
        name = name.to_sym
        registered_modules[name] = config_class
        define_method(name) { module_config(name) }
      end

      private

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@registered_modules, registered_modules.dup)
      end
    end

    # @return [String] the pinned defaults version
    attr_reader :defaults

    def initialize
      # Unpinned configurations get the oldest known defaults, mirroring Rails:
      # new behavior must always be opted into via an explicit pin.
      @defaults = KNOWN_DEFAULTS_VERSIONS.first
      @module_configs = {}
    end

    # Pins the defaults version.
    #
    # @param version [String, Float] e.g. `"1.0"`
    # @raise [Forseti::ConfigurationError] for versions this release doesn't know
    def defaults=(version)
      version = version.to_s
      unless KNOWN_DEFAULTS_VERSIONS.include?(version)
        raise ConfigurationError,
              "Unknown Forseti defaults version #{version.inspect}. " \
              "Known versions: #{KNOWN_DEFAULTS_VERSIONS.join(', ')}"
      end

      @defaults = version
    end

    # Validates every module configuration that has been touched. Settings are
    # also validated on assignment; this pass exists for cross-setting rules.
    #
    # @return [true]
    # @raise [Forseti::ConfigurationError]
    def validate!
      @module_configs.each_value(&:validate!)
      true
    end

    private

    def module_config(name)
      @module_configs[name] ||= begin
        config_class = self.class.registered_modules.fetch(name)
        config_class = Object.const_get(config_class) if config_class.is_a?(String)
        config_class.new(self)
      end
    end

    def method_missing(name, *)
      raise ConfigurationError,
            "Unknown Forseti module or setting `#{name.to_s.delete_suffix('=')}`. " \
            "Registered modules: #{self.class.registered_modules.keys.sort.join(', ')}"
    end

    def respond_to_missing?(name, include_private = false)
      super
    end
  end
end
