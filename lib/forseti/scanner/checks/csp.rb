# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class CSP < Check
        id          "security.csp"
        severity    :high
        title       "Content Security Policy"
        description "A CSP is the strongest browser-side mitigation against XSS and injection of " \
                    "third-party content."
        remediation "Define a policy in config/initializers/content_security_policy.rb using Rails' " \
                    "built-in DSL. Start in report-only mode if needed."

        def call
          policy = context.config.content_security_policy

          if policy.nil?
            fail_with("No Content Security Policy is configured")
          elsif context.config.content_security_policy_report_only
            pass("CSP configured (report-only mode)",
                 details: ["Policy is report-only: violations are logged, not blocked. " \
                           "Move to enforcing mode once reports are clean."])
          else
            pass("CSP configured and enforcing")
          end
        end
      end
    end
  end
end
