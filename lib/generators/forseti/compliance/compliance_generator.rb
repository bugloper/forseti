# frozen_string_literal: true

require "rails/generators"
require "rails/generators/base"

module Forseti
  module Generators
    class ComplianceGenerator < Rails::Generators::Base
      desc "Creates the attestations file skeleton at config/forseti/attestations.yml"

      def create_attestations_file
        create_file "config/forseti/attestations.yml", attestations_skeleton
      end

      def show_next_steps
        say ""
        say "Attestations skeleton generated. Next steps:", :green
        say "  1. Enable policies: `config.compliance.enable :gdpr` in the Forseti initializer."
        say "  2. Uncomment and fill attestations as your organization satisfies each requirement."
        say "  3. Run `bin/rails forseti:compliance` for the report."
      end

      private

      def attestations_skeleton
        header = <<~YAML
          # Forseti compliance attestations (ADR 005).
          #
          # Requirements that cannot be machine-verified are satisfied ONLY by an
          # explicit attestation here: who, when, and optionally until when. This
          # file lives in git on purpose — review attestations like code.
          #
          # Reports always distinguish "attested" from "machine-verified".
        YAML

        sections = Forseti::Compliance.registry.values.map { |policy| policy_section(policy) }
        header + sections.join
      end

      def policy_section(policy)
        lines = ["\n# #{policy.name}", "# #{policy.key}:"]
        policy.requirements.select { |r| r.kind == :attestable }.each do |requirement|
          lines << "#   #{requirement.key}:                # #{requirement.article} — #{requirement.title}"
          lines << "#     attested_by: \"name@example.com\""
          lines << "#     attested_on: #{Date.current.iso8601}"
          lines << "#     note: \"\""
        end
        "#{lines.join("\n")}\n"
      end
    end
  end
end
