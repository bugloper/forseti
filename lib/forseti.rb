# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/integer/time"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/object/blank"
require "zeitwerk"

require_relative "forseti/version"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "ansi" => "ANSI",
  "ccpa" => "CCPA",
  "cli" => "CLI",
  "csp" => "CSP",
  "csp_nonce" => "CSPNonce",
  "dpdp" => "DPDP",
  "gdpr" => "GDPR",
  "hsts" => "HSTS",
  "json" => "JSON",
  "lgpd" => "LGPD",
  "pii" => "PII",
  "tty" => "TTY",
  "tty_formatter" => "TTYFormatter"
)
loader.ignore("#{__dir__}/forseti/version.rb")
loader.ignore("#{__dir__}/forseti/engine.rb")
loader.ignore("#{__dir__}/forseti/tasks.rb")
loader.ignore("#{__dir__}/generators")
loader.setup

# Forseti is a security and compliance framework for Ruby on Rails.
#
# Applications configure it from an initializer:
#
#   Forseti.configure do |config|
#     config.defaults = "1.0"
#   end
module Forseti
  class << self
    # The gem's Zeitwerk loader. Internal; used by Forseti.eager_load!.
    attr_accessor :loader
  end

  # Eager loads the gem's own code (not the engine's app/ directory, which
  # belongs to the host app's autoloader and may require Active Record).
  #
  # @return [void]
  def self.eager_load!
    loader.eager_load
  end

  # Raised for any Forseti-specific failure. All Forseti errors inherit from
  # this class so applications can rescue the whole family at once.
  class Error < StandardError; end

  # Raised when Forseti is configured with invalid or unknown values.
  class ConfigurationError < Error; end

  # Raised when reading or writing a setting that a configuration object does
  # not declare. The message lists the valid alternatives.
  class UnknownSettingError < ConfigurationError; end

  # Raised when a declared setting is assigned a value outside its allowed
  # values or type.
  class InvalidSettingError < ConfigurationError; end

  class << self
    # The global configuration. Prefer {.configure} for writing.
    #
    # @return [Forseti::Configuration]
    def config
      @config ||= Configuration.new
    end

    # Yields the global configuration and validates it afterwards.
    #
    #   Forseti.configure do |config|
    #     config.defaults = "1.0"
    #   end
    #
    # @yieldparam config [Forseti::Configuration]
    # @return [Forseti::Configuration]
    def configure
      yield config if block_given?
      config.validate!
      config
    end

    # Discards the global configuration. Intended for test suites.
    #
    # @return [void]
    def reset_configuration!
      @config = nil
    end
  end
end

# Module configurations are registered as constant names so that referencing
# `Forseti.config.scanner` autoloads the module lazily (ADR 000, D1).
Forseti::Configuration.register_module(:scanner, "Forseti::Scanner::Config")
Forseti::Configuration.register_module(:security, "Forseti::Security::Config")
Forseti::Configuration.register_module(:privacy, "Forseti::Privacy::Config")
Forseti::Configuration.register_module(:audit, "Forseti::Audit::Config")
Forseti::Configuration.register_module(:compliance, "Forseti::Compliance::Config")
Forseti::Configuration.register_module(:consent, "Forseti::Consent::Config")
Forseti::Configuration.register_module(:retention, "Forseti::Retention::Config")

Forseti.loader = loader

require_relative "forseti/engine" if defined?(Rails::Engine)
