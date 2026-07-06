# frozen_string_literal: true

RSpec.describe Forseti do
  it "has a version number" do
    expect(Forseti::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  describe ".config" do
    it "memoizes a global configuration" do
      expect(described_class.config).to be_a(Forseti::Configuration)
      expect(described_class.config).to equal(described_class.config)
    end
  end

  describe ".configure" do
    it "yields the global configuration and returns it" do
      yielded = nil
      returned = described_class.configure { |config| yielded = config }

      expect(yielded).to equal(described_class.config)
      expect(returned).to equal(described_class.config)
    end

    it "validates the configuration after the block" do
      allow(described_class.config).to receive(:validate!)
      described_class.configure { |config| config.defaults = "1.0" }

      expect(described_class.config).to have_received(:validate!)
    end
  end

  describe ".reset_configuration!" do
    it "discards the memoized configuration" do
      before_reset = described_class.config
      described_class.reset_configuration!

      expect(described_class.config).not_to equal(before_reset)
    end
  end

  describe "error hierarchy" do
    it "roots every Forseti error at Forseti::Error" do
      expect(Forseti::ConfigurationError.ancestors).to include(Forseti::Error)
      expect(Forseti::UnknownSettingError.ancestors).to include(Forseti::ConfigurationError)
      expect(Forseti::InvalidSettingError.ancestors).to include(Forseti::ConfigurationError)
    end
  end
end
