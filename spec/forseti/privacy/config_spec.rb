# frozen_string_literal: true

RSpec.describe Forseti::Privacy::Config do
  it "is registered lazily as Forseti.config.privacy" do
    expect(Forseti.config.privacy).to be_a(described_class)
  end

  it "defaults everything off" do
    config = described_class.new

    expect(config.filter_parameters_mode).to eq(:off)
    expect(config.log_redaction_mode).to eq(:off)
    expect(config.redact_types).to eq(%i[email credit_card ssn])
    expect(config.active?).to be(false)
  end

  describe "#enable!" do
    it "enforces filtering and starts redaction in report mode" do
      config = described_class.new.enable!

      expect(config.filter_parameters_mode).to eq(:enforce)
      expect(config.log_redaction_mode).to eq(:report)
    end

    it "does not downgrade an explicitly chosen redaction mode" do
      config = described_class.new
      config.log_redaction_mode = :enforce
      config.enable!

      expect(config.log_redaction_mode).to eq(:enforce)
    end
  end

  describe "#filter_parameters!" do
    it "opts into parameter filtering alone" do
      config = described_class.new.filter_parameters!

      expect(config.filter_parameters_mode).to eq(:enforce)
      expect(config.log_redaction_mode).to eq(:off)
      expect(config.active?).to be(true)
    end
  end
end
