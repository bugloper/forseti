# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class Cookies < Check
        id          "security.cookies"
        severity    :high
        title       "Cookie and session hardening"
        description "Session cookies should be HttpOnly, SameSite-protected, and Secure in production."
        remediation "Keep cookies_same_site_protection at :lax or stricter, don't disable httponly on the " \
                    "session store, and rely on force_ssl (or `secure: true`) for the Secure flag."

        def call
          problems = []
          problems << same_site_problem
          problems << httponly_problem
          problems << secure_problem if context.production_like?
          problems.compact!

          if problems.empty?
            pass("Session cookie settings are hardened")
          else
            fail_with("Cookie settings weaken session protection", details: problems)
          end
        end

        private

        def session_options
          context.config.session_options || {}
        end

        def same_site_problem
          return if context.config.action_dispatch.cookies_same_site_protection

          "action_dispatch.cookies_same_site_protection is unset — cookies default to SameSite=None behavior"
        end

        def httponly_problem
          return unless session_options[:httponly] == false

          "The session cookie sets httponly: false, exposing it to JavaScript (XSS escalation)"
        end

        def secure_problem
          return if session_options[:secure] || context.config.force_ssl

          "Session cookie is not Secure: neither `secure: true` nor force_ssl is set"
        end
      end
    end
  end
end
