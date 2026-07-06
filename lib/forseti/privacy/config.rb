# frozen_string_literal: true

module Forseti
  module Privacy
    # Privacy module configuration, available as +Forseti.config.privacy+.
    #
    # `enable!` opts into the recommended posture: PII-registry-driven
    # parameter filtering, and log redaction in report-only mode. Moving
    # redaction to :enforce is a deliberate second step — mirror of ADR 002's
    # CSP rollout.
    class Config < Forseti::Config::Base
      setting :filter_parameters_mode,
              default: versioned("1.0" => :off),
              values: %i[off enforce],
              description: "Union Forseti::PII.filter_keys into config.filter_parameters at boot. " \
                           "Never removes the app's own entries."

      setting :log_redaction_mode,
              default: versioned("1.0" => :off),
              values: MODES,
              description: ":report detects PII in log lines and instruments pii_detected.forseti; " \
                           ":enforce replaces matches with [REDACTED:<type>]."

      setting :redact_types,
              default: versioned("1.0" => %i[email credit_card ssn]),
              description: "PII type keys the log redactor scans for. Only value-pattern types apply; " \
                           "phone and ip_address are deliberately not defaults (they mangle request logs)."

      # The vision API: opt into parameter filtering alone.
      #
      # @return [self]
      def filter_parameters!
        self.filter_parameters_mode = :enforce
        self
      end

      # Whether any privacy feature needs boot-time wiring.
      def active?
        enabled? || filter_parameters_mode != :off || log_redaction_mode != :off
      end

      private

      def apply_recommended_defaults!
        self.filter_parameters_mode = :enforce
        # Don't downgrade an explicitly chosen :enforce.
        self.log_redaction_mode = :report if log_redaction_mode == :off
      end
    end
  end
end
