# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class ForceSsl < Check
        id          "security.force_ssl"
        severity    :critical
        title       "HTTPS enforced"
        description "config.force_ssl redirects HTTP to HTTPS, marks cookies secure, and enables HSTS."
        remediation "Set `config.force_ssl = true` in config/environments/production.rb. Use " \
                    "`config.ssl_options` to exempt health-check endpoints instead of turning it off."
        production_only

        def call
          if context.config.force_ssl
            pass("config.force_ssl is enabled")
          else
            fail_with("config.force_ssl is disabled — traffic and cookies can travel over plaintext HTTP")
          end
        end
      end
    end
  end
end
