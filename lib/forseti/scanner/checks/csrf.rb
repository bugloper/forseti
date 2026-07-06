# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class Csrf < Check
        id          "security.csrf"
        severity    :high
        title       "CSRF protection"
        description "Rails protects against cross-site request forgery when default_protect_from_forgery " \
                    "is on; origin checking hardens it further."
        remediation "Keep `config.action_controller.default_protect_from_forgery = true` (load_defaults " \
                    "5.2+) and enable `forgery_protection_origin_check`."

        def call
          ac = context.config.action_controller

          if ac.default_protect_from_forgery == false
            fail_with("default_protect_from_forgery is explicitly disabled")
          elsif ac.default_protect_from_forgery.nil?
            fail_with("default_protect_from_forgery is unset — controllers are unprotected unless they " \
                      "call protect_from_forgery themselves")
          elsif ac.forgery_protection_origin_check == false
            fail_with("CSRF protection is on, but forgery_protection_origin_check is disabled",
                      details: ["Origin-header checking blocks token-leak CSRF variants; re-enable it."])
          else
            pass("CSRF protection enabled")
          end
        end
      end
    end
  end
end
