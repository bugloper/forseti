# frozen_string_literal: true

module Forseti
  module Compliance
    module Policies
      # California Consumer Privacy Act (as amended by CPRA).
      module CCPA
        def self.policy # rubocop:disable Metrics/MethodLength -- a declaration, not logic
          Policy.define(:ccpa,
                        name: "California Consumer Privacy Act",
                        version: "Cal. Civ. Code §1798.100 (CPRA-amended)") do |p|
            p.requirement :privacy_policy_disclosure,
                          article: "§1798.130",
                          title: "Privacy policy discloses categories collected, sold, and shared"

            p.requirement :right_to_know,
                          article: "§1798.110",
                          title: "Consumers can request the personal information held about them"

            p.requirement :right_to_delete,
                          article: "§1798.105",
                          title: "Consumers can request deletion of their personal information"

            p.requirement :opt_out_of_sale,
                          article: "§1798.120",
                          title: "A 'Do Not Sell or Share My Personal Information' mechanism is offered"

            p.requirement :non_discrimination,
                          article: "§1798.125",
                          title: "Exercising rights does not degrade service or pricing"

            p.requirement :reasonable_security,
                          article: "§1798.150",
                          title: "Reasonable security procedures protect personal information",
                          checks: %w[security.force_ssl security.cookies privacy.filter_parameters],
                          remediation: "Fix the failing checks listed by bin/rails forseti:doctor."

            p.requirement :service_provider_contracts,
                          article: "§1798.140",
                          title: "Service-provider and contractor agreements restrict data use"
          end
        end
      end
    end
  end
end
