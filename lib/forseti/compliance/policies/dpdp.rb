# frozen_string_literal: true

module Forseti
  module Compliance
    module Policies
      # India's Digital Personal Data Protection Act.
      module DPDP
        def self.policy # rubocop:disable Metrics/MethodLength -- a declaration, not logic
          Policy.define(:dpdp,
                        name: "Digital Personal Data Protection Act (India)",
                        version: "No. 22 of 2023") do |p|
            p.requirement :notice_and_consent,
                          article: "§5–6",
                          title: "Notice is given and consent obtained before processing",
                          verify: -> { Forseti.config.consent.enabled? },
                          evidence: "config.consent.enabled?",
                          or_attested: true,
                          remediation: "Enable config.consent.enable! and record consent through " \
                                       "Forseti::Consent, or attest to your external consent system."

            p.requirement :security_safeguards,
                          article: "§8(5)",
                          title: "Reasonable security safeguards prevent personal data breaches",
                          checks: %w[security.force_ssl security.cookies privacy.filter_parameters],
                          remediation: "Fix the failing checks listed by bin/rails forseti:doctor."

            p.requirement :breach_notification_readiness,
                          article: "§8(6)",
                          title: "Breaches can be detected, reconstructed, and reported to the Board",
                          verify: -> { Forseti.config.audit.enabled? },
                          evidence: "config.audit.enabled?",
                          remediation: "Enable config.audit.enable! so incidents leave a trail."

            p.requirement :erasure_on_withdrawal,
                          article: "§8(7)",
                          title: "Personal data is erased when consent is withdrawn or purpose served"

            p.requirement :grievance_officer,
                          article: "§13",
                          title: "A grievance redressal contact is published and responsive"

            p.requirement :children_data,
                          article: "§9",
                          title: "Verifiable parental consent is obtained for children's data"
          end
        end
      end
    end
  end
end
