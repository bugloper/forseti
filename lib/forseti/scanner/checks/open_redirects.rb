# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class OpenRedirects < Check
        id          "security.open_redirects"
        severity    :medium
        title       "Open redirect protection"
        description "Rails can block redirect_to targets on other hosts unless explicitly allowed, " \
                    "preventing phishing-grade open redirects."
        remediation "Set `config.action_controller.action_on_open_redirect = :raise` (Rails 8.1+, default " \
                    "with load_defaults 8.1) or `raise_on_open_redirects = true` (Rails ≤ 8.0, default " \
                    "with load_defaults 7.0). Mark intentional external redirects with " \
                    "`allow_other_host: true`."

        def call
          action = context.config.action_controller.action_on_open_redirect
          # Rails 8.1 replaced the boolean raise_on_open_redirects with
          # action_on_open_redirect (:raise/:log/:notify); nil means the app
          # runs on the legacy setting.
          return legacy_call if action.nil?

          if action.to_s == "raise"
            pass("Cross-origin redirects raise unless explicitly allowed")
          else
            fail_with("action_on_open_redirect is :#{action} — open redirects are reported, not blocked")
          end
        end

        private

        def legacy_call
          if context.config.action_controller.raise_on_open_redirects
            pass("redirect_to raises on unexpected cross-origin redirects")
          else
            fail_with("raise_on_open_redirects is off — user-controlled redirect targets are not blocked")
          end
        end
      end
    end
  end
end
