# frozen_string_literal: true

module Forseti
  module Security
    # Security module configuration, available as +Forseti.config.security+.
    #
    # `enable!` opts into the recommended posture: fill missing security
    # headers, and ship the baseline CSP in report-only mode. Moving CSP to
    # :enforce is a deliberate second step once reports look clean.
    class Config < Forseti::Config::Base
      # The report-only-first baseline (ADR 002 §7). No nonce support here on
      # purpose — apps needing nonces should graduate to Rails' CSP DSL.
      BASELINE_CSP = "default-src 'self'; script-src 'self'; style-src 'self'; " \
                     "img-src 'self' data:; font-src 'self' data:; object-src 'none'; " \
                     "frame-ancestors 'self'; base-uri 'self'; form-action 'self'"

      setting :headers_mode,
              default: versioned("1.0" => :off),
              values: %i[off enforce],
              description: "Fill missing baseline security headers on responses. Never overrides " \
                           "headers the app already sets."

      setting :csp_mode,
              default: versioned("1.0" => :off),
              values: MODES,
              description: "Add the baseline Content-Security-Policy to HTML responses that have " \
                           "none. :report sends Content-Security-Policy-Report-Only."

      setting :frame_options,
              default: "SAMEORIGIN",
              values: %w[SAMEORIGIN DENY],
              description: "X-Frame-Options value used when filling."

      setting :referrer_policy,
              default: "strict-origin-when-cross-origin",
              description: "Referrer-Policy value used when filling."

      setting :csp_policy,
              default: versioned("1.0" => BASELINE_CSP),
              description: "The policy string applied by csp_mode."

      setting :csp_report_uri,
              default: nil,
              description: "Appended to the policy as a report-uri directive when set."

      # Whether the middleware belongs in the stack: either the module was
      # enabled wholesale, or an individual feature was dialed on.
      def active?
        enabled? || headers_mode != :off || csp_mode != :off
      end

      private

      def apply_recommended_defaults!
        self.headers_mode = :enforce
        # Don't downgrade an explicitly chosen :enforce.
        self.csp_mode = :report if csp_mode == :off
      end
    end
  end
end
