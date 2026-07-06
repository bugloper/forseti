# frozen_string_literal: true

require "rails"
# Only the frameworks the dummy app needs. Active Record is deliberately
# absent: Forseti's core must work without it (ADR 000, D2).
require "action_controller/railtie"

require "forseti"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.logger = Logger.new(IO::NULL)
    config.secret_key_base = "dummy-secret-key-base-for-tests"
  end
end
