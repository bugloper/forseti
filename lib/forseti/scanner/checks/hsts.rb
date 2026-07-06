# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class HSTS < Check
        ONE_YEAR = 31_536_000

        id          "security.hsts"
        severity    :high
        title       "HTTP Strict Transport Security"
        description "HSTS instructs browsers to refuse plaintext connections for the policy's lifetime."
        remediation "Remove `hsts: false` from config.ssl_options, or raise expires_in to at least one year."
        production_only

        def applies?
          !!context.config.force_ssl
        end

        def not_applicable_reason
          "Requires force_ssl (see security.force_ssl)"
        end

        def call
          hsts = (context.config.ssl_options || {})[:hsts]

          case hsts
          when false
            fail_with("HSTS is explicitly disabled via config.ssl_options[:hsts]")
          when Hash
            check_expiry(hsts)
          else
            pass("HSTS active with Rails' default policy")
          end
        end

        private

        def check_expiry(hsts)
          expires_in = hsts[:expires_in]
          if expires_in && expires_in.to_i < ONE_YEAR
            fail_with("HSTS expires_in is #{expires_in.to_i}s — below the one-year minimum browsers expect")
          else
            pass("HSTS active with a custom policy")
          end
        end
      end
    end
  end
end
