# frozen_string_literal: true

module Forseti
  module Compliance
    module Policies
      # Brazil's Lei Geral de Proteção de Dados.
      module LGPD
        def self.policy # rubocop:disable Metrics/MethodLength -- a declaration, not logic
          Policy.define(:lgpd,
                        name: "Lei Geral de Proteção de Dados (Brazil)",
                        version: "Lei nº 13.709/2018") do |p|
            p.requirement :legal_basis,
                          article: "Art. 7",
                          title: "Each processing activity rests on a documented legal basis"

            p.requirement :encarregado_appointed,
                          article: "Art. 41",
                          title: "A Data Protection Officer (encarregado) is designated"

            p.requirement :security_measures,
                          article: "Art. 46",
                          title: "Technical measures protect personal data from unauthorized access",
                          checks: %w[security.force_ssl security.cookies privacy.filter_parameters],
                          remediation: "Fix the failing checks listed by bin/rails forseti:doctor."

            p.requirement :data_subject_rights,
                          article: "Art. 18",
                          title: "Subjects can access, correct, delete, and port their data"

            p.requirement :processing_records,
                          article: "Art. 37",
                          title: "Records of processing operations are maintained"

            p.requirement :breach_notification_readiness,
                          article: "Art. 48",
                          title: "Incidents can be reconstructed and reported to the ANPD",
                          verify: -> { Forseti.config.audit.enabled? },
                          evidence: "config.audit.enabled?",
                          remediation: "Enable config.audit.enable! so incidents leave a trail."
          end
        end
      end
    end
  end
end
