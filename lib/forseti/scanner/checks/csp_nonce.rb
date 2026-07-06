# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class CSPNonce < Check
        id          "security.csp_nonce"
        severity    :low
        title       "CSP nonce generator"
        description "Per-request nonces allow a strict script-src without 'unsafe-inline'."
        remediation "Set `config.content_security_policy_nonce_generator = " \
                    "->(request) { request.session.id.to_s }` (or SecureRandom-based) in the CSP initializer."

        def applies?
          !context.config.content_security_policy.nil?
        end

        def not_applicable_reason
          "No Content Security Policy configured (see security.csp)"
        end

        def call
          if context.config.content_security_policy_nonce_generator
            pass("CSP nonce generator configured")
          else
            fail_with("No nonce generator — inline scripts require 'unsafe-inline', weakening the policy")
          end
        end
      end
    end
  end
end
