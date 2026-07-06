# frozen_string_literal: true

require "tmpdir"

RSpec.describe Forseti::Compliance::Attestations do
  describe ".load" do
    def write_attestations(dir)
      File.join(dir, "attestations.yml").tap do |path|
        File.write(path, <<~YAML)
          gdpr:
            records_of_processing:
              attested_by: "jane@corp.com"
              attested_on: 2026-07-01
              note: "RoPA in LEG-12"
        YAML
      end
    end

    it "loads a YAML file with dates and answers lookups" do
      Dir.mktmpdir do |dir|
        attestation = described_class.load(write_attestations(dir)).for(:gdpr, :records_of_processing)

        expect(attestation).to be_valid
        expect(attestation.attested_by).to eq("jane@corp.com")
        expect(attestation.attested_on).to eq(Date.new(2026, 7, 1))
      end
    end

    it "returns an empty set when the file does not exist" do
      expect(described_class.load("/nonexistent/attestations.yml").for(:gdpr, :anything)).to be_nil
    end
  end

  describe "validity" do
    it "requires who and when" do
      expect(described_class::Attestation.new(attested_by: "", attested_on: Date.current)).not_to be_valid
      expect(described_class::Attestation.new(attested_by: "x", attested_on: nil)).not_to be_valid
      expect(described_class::Attestation.new(attested_by: "x", attested_on: Date.current)).to be_valid
    end

    it "treats future expiry as valid and past expiry as expired" do
      base = { attested_by: "x", attested_on: Date.new(2026, 1, 1) }

      expect(described_class::Attestation.new(**base, expires_on: Date.current + 30)).to be_valid
      expired = described_class::Attestation.new(**base, expires_on: Date.current - 1)
      expect(expired).not_to be_valid
      expect(expired).to be_expired
    end
  end
end
