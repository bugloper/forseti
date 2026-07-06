# frozen_string_literal: true

module Forseti
  module Compliance
    module Policies
      # EU General Data Protection Regulation. The reference policy: technical
      # controls are checkable today; data-subject rights are attestable until
      # Phase 6 (Consent/Retention) gives Forseti something to verify.
      module GDPR
        def self.policy # rubocop:disable Metrics/MethodLength -- a declaration, not logic
          Policy.define(:gdpr,
                        name: "EU General Data Protection Regulation",
                        version: "Regulation (EU) 2016/679") do |p|
            p.requirement :records_of_processing,
                          article: "Art. 30",
                          title: "Records of processing activities are maintained",
                          remediation: "Maintain a RoPA and attest to it in attestations.yml."

            p.requirement :lawful_basis,
                          article: "Art. 6",
                          title: "A lawful basis is documented for each processing activity"

            p.requirement :privacy_notice,
                          article: "Art. 13/14",
                          title: "Privacy notices are provided at collection"

            p.requirement :consent_management,
                          article: "Art. 7",
                          title: "Consent is collected, stored, and withdrawable where relied upon"

            p.requirement :security_of_processing,
                          article: "Art. 32",
                          title: "Appropriate technical security measures are in place",
                          checks: %w[security.force_ssl security.hsts security.cookies security.csp],
                          remediation: "Fix the failing checks listed by bin/rails forseti:doctor."

            p.requirement :data_minimization_in_logs,
                          article: "Art. 5(1)(c)",
                          title: "Logs and telemetry minimize personal data",
                          checks: %w[privacy.filter_parameters privacy.log_level],
                          remediation: "Enable config.privacy.enable! and fix the failing checks."

            p.requirement :accountability_trail,
                          article: "Art. 5(2) / 33",
                          title: "Security-relevant actions leave an audit trail supporting breach analysis",
                          verify: -> { Forseti.config.audit.enabled? },
                          evidence: "config.audit.enabled?",
                          checks: %w[audit.storage],
                          remediation: "Enable config.audit.enable! and migrate its storage."

            p.requirement :right_to_erasure,
                          article: "Art. 17",
                          title: "Personal data can be erased on request within the statutory window"

            p.requirement :data_portability,
                          article: "Art. 20",
                          title: "Subjects can export their data in a machine-readable format"

            p.requirement :dpo_appointed,
                          article: "Art. 37",
                          title: "A Data Protection Officer is appointed (where required)"

            p.requirement :international_transfers,
                          article: "Ch. V",
                          title: "Cross-border transfers use a valid mechanism (SCCs, adequacy, ...)"
          end
        end
      end
    end
  end
end
