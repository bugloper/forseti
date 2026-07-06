# frozen_string_literal: true

require "tmpdir"
require "generators/forseti/compliance/compliance_generator"

RSpec.describe Forseti::Generators::ComplianceGenerator do
  it "creates a commented attestations skeleton covering every policy's attestable requirements" do
    Dir.mktmpdir do |dir|
      capture_stdout { described_class.start([], destination_root: dir) }

      content = File.read(File.join(dir, "config/forseti/attestations.yml"))

      expect(content).to include("# gdpr:", "# ccpa:", "# lgpd:", "# dpdp:")
      expect(content).to include("records_of_processing:", "grievance_officer:")
      # Everything ships commented out — attesting is always an explicit act.
      expect(YAML.safe_load(content, permitted_classes: [Date])).to be_nil
    end
  end
end
