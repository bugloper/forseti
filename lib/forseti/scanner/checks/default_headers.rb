# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class DefaultHeaders < Check
        REQUIRED = %w[X-Content-Type-Options X-Frame-Options Referrer-Policy].freeze

        id          "security.default_headers"
        severity    :medium
        title       "Baseline security headers"
        description "Rails ships X-Content-Type-Options, X-Frame-Options, and Referrer-Policy by default; " \
                    "apps sometimes strip them."
        remediation "Restore the missing headers via config.action_dispatch.default_headers in " \
                    "config/application.rb."

        def call
          headers = context.config.action_dispatch.default_headers || {}
          missing = REQUIRED - headers.keys
          # frame-ancestors is the modern replacement for X-Frame-Options.
          missing.delete("X-Frame-Options") if csp_covers_framing?

          if missing.empty?
            pass("Baseline security headers present")
          else
            fail_with("Missing default security headers", details: missing.map { |h| "#{h} is not set" })
          end
        end

        private

        def csp_covers_framing?
          directives = context.config.content_security_policy&.directives
          directives&.key?("frame-ancestors") || false
        end
      end
    end
  end
end
