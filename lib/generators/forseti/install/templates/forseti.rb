# frozen_string_literal: true

Forseti.configure do |config|
  # Pin the Forseti defaults generation (works like Rails' load_defaults):
  # upgrading the gem never changes behavior until you bump this pin.
  config.defaults = "1.0"

  # == Scanner =================================================================
  # Run `bin/rails forseti:doctor` for a scored security posture report.
  # In CI, doctor exits 1 when a failed check is at least this severe:
  #
  # config.scanner.fail_on = :high
  # config.scanner.skip_checks = ["security.csp_nonce"]

  # == Security ================================================================
  # One-line hardening: fills missing security headers on every response and
  # adds a baseline Content-Security-Policy in report-only mode to HTML
  # responses that have none. Headers your app already sets always win.
  #
  # config.security.enable!
  #
  # Individual dials (see each header's docs before tightening):
  #
  # config.security.frame_options   = "DENY"          # default "SAMEORIGIN"
  # config.security.referrer_policy = "no-referrer"   # default "strict-origin-when-cross-origin"
  # config.security.csp_report_uri  = "https://example.report-uri.com/r/d/csp"
  #
  # Once report-only CSP looks clean in production, enforce it:
  #
  # config.security.csp_mode = :enforce

  # == Privacy =================================================================
  # PII-registry-driven protection: extends config.filter_parameters with
  # Forseti's PII filter keys (never removes yours) and detects PII in log
  # lines, reporting via the pii_detected.forseti notification.
  #
  # config.privacy.enable!
  #
  # When reports look right, actually redact matches from log lines:
  #
  # config.privacy.log_redaction_mode = :enforce
  # config.privacy.redact_types = %i[email credit_card ssn iban]

  # == Audit ===================================================================
  # Durable, append-only trail of security events. Requires storage first:
  # `bin/rails generate forseti:audit && bin/rails db:migrate` (or use the
  # database-free :logger sink).
  #
  # config.audit.enable!
  # config.audit.sinks = [:active_record]     # and/or :logger, or any #write(event)
  # config.audit.on_sink_error = :report      # :raise to fail closed
  #
  # Then record events anywhere:
  #   Forseti::Audit.record(:role_changed, actor: admin, subject: user,
  #                         metadata: { from: "member", to: "admin" })
  # and include Forseti::Audit::Controller in ApplicationController to fill
  # actor/ip/request context automatically.

  # == Compliance ==============================================================
  # Map your posture to regulations. Machine-checkable requirements are
  # verified against the live app; everything else needs an explicit human
  # attestation (generate the file with `rails g forseti:compliance`).
  # Report with `bin/rails forseti:compliance` (FORMAT=json for CI).
  #
  # config.compliance.enable :gdpr    # also: :ccpa, :lgpd, :dpdp
  #
  # Forseti provides technical evidence, not legal advice — a passing report
  # does not constitute or guarantee regulatory compliance.
end

# Teach every Forseti layer about domain-specific PII at once (filtering,
# log redaction, scanner coverage):
#
# Forseti::PII.register(:employee_badge,
#                       sensitivity: :medium,
#                       key_patterns: [/badge (number|id)/],
#                       filter_keys: %i[badge_number])
