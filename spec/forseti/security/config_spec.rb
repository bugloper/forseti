# frozen_string_literal: true

RSpec.describe Forseti::Security::Config do
  it "is registered lazily as Forseti.config.security" do
    expect(Forseti.config.security).to be_a(described_class)
  end

  it "defaults everything off — installing changes nothing" do
    config = described_class.new

    expect(config.headers_mode).to eq(:off)
    expect(config.csp_mode).to eq(:off)
    expect(config.active?).to be(false)
  end

  describe "#enable!" do
    it "enforces headers and starts CSP in report-only mode" do
      config = described_class.new.enable!

      expect(config.headers_mode).to eq(:enforce)
      expect(config.csp_mode).to eq(:report)
      expect(config.active?).to be(true)
    end

    it "does not downgrade an explicitly chosen csp_mode" do
      config = described_class.new
      config.csp_mode = :enforce
      config.enable!

      expect(config.csp_mode).to eq(:enforce)
    end
  end

  describe "#active?" do
    it "is true when any individual feature is dialed on without enable!" do
      config = described_class.new
      config.csp_mode = :report

      expect(config.active?).to be(true)
    end
  end

  it "validates header values" do
    config = described_class.new

    expect { config.frame_options = "ALLOWALL" }.to raise_error(Forseti::InvalidSettingError)
    expect { config.headers_mode = :report }.to raise_error(Forseti::InvalidSettingError)
  end
end
