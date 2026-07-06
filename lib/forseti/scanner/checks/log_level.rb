# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class LogLevel < Check
        id          "privacy.log_level"
        severity    :medium
        title       "Production log level"
        description "Debug-level production logs capture SQL with bound values and verbose request data — " \
                    "a common PII leak."
        remediation "Set `config.log_level = :info` in config/environments/production.rb."
        production_only

        def call
          level = context.config.log_level

          if level.to_s == "debug"
            fail_with("Production log level is :debug — query values and verbose request data are logged")
          else
            pass("Log level is :#{level}")
          end
        end
      end
    end
  end
end
