# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class CSP < Check
        REPORT_ONLY_CAVEAT = "Policy is report-only: violations are logged, not blocked. " \
                             "Move to enforcing mode once reports are clean."

        id          "security.csp"
        severity    :high
        title       "Content Security Policy"
        description "A CSP is the strongest browser-side mitigation against XSS and injection of " \
                    "third-party content."
        remediation "Define a policy in config/initializers/content_security_policy.rb using Rails' " \
                    "built-in DSL, or opt into Forseti's baseline with config.security.enable!. " \
                    "Start in report-only mode if needed."

        def call
          if context.config.content_security_policy
            rails_csp_verdict
          elsif forseti_csp_active?
            forseti_csp_verdict
          elsif defined?(::SecureHeaders)
            secure_headers_verdict
          else
            fail_with("No Content Security Policy is configured")
          end
        end

        private

        def rails_csp_verdict
          if context.config.content_security_policy_report_only
            pass("CSP configured (report-only mode)", details: [REPORT_ONLY_CAVEAT])
          else
            pass("CSP configured and enforcing")
          end
        end

        def forseti_csp_active?
          Forseti.config.security.csp_mode != :off
        end

        def forseti_csp_verdict
          if Forseti.config.security.csp_mode == :enforce
            pass("Baseline CSP enforced by Forseti")
          else
            pass("Baseline CSP applied by Forseti (report-only mode)", details: [REPORT_ONLY_CAVEAT])
          end
        end

        # The secure_headers gem (archived upstream) manages CSP outside Rails'
        # config. Introspect defensively; a real-world footgun is a policy
        # defined and then overridden with SecureHeaders::OPT_OUT.
        def secure_headers_verdict
          csp = secure_headers_csp

          if secure_headers_opt_out?(csp)
            fail_with("The secure_headers gem has CSP opted out (SecureHeaders::OPT_OUT) — " \
                      "any policy defined above the opt-out line is dead configuration")
          else
            pass("CSP managed by the secure_headers gem")
          end
        rescue StandardError
          skip("CSP appears managed by the secure_headers gem (could not introspect its configuration)")
        end

        # secure_headers 7.x exposes the default config via Configuration.dup;
        # older releases via Configuration.get. Try both.
        def secure_headers_csp
          configuration = ::SecureHeaders::Configuration
          duped = configuration.dup
          return duped.csp if duped.respond_to?(:csp)

          configuration.get.csp
        end

        def secure_headers_opt_out?(csp)
          (defined?(::SecureHeaders::OPT_OUT) && csp == ::SecureHeaders::OPT_OUT) ||
            (csp.respond_to?(:opt_out?) && csp.opt_out?)
        end
      end
    end
  end
end
