# frozen_string_literal: true

RSpec.describe Forseti::Configuration do
  # Register test modules on an anonymous subclass so the real Configuration
  # class is never polluted across examples.
  let(:configuration_class) { Class.new(described_class) }
  let(:module_config_class) do
    Class.new(Forseti::Config::Base) do
      def self.name = "Fake::Config"
    end
  end

  describe "#defaults" do
    it "falls back to the oldest known defaults version when unpinned" do
      expect(configuration_class.new.defaults).to eq(described_class::KNOWN_DEFAULTS_VERSIONS.first)
    end

    it "accepts known versions, including as floats" do
      config = configuration_class.new
      config.defaults = 1.0

      expect(config.defaults).to eq("1.0")
    end

    it "rejects unknown versions with the known ones listed" do
      expect { configuration_class.new.defaults = "99.0" }
        .to raise_error(Forseti::ConfigurationError, /99\.0.*Known versions: 1\.0/)
    end
  end

  describe ".register_module" do
    it "defines a memoized accessor for the module configuration" do
      configuration_class.register_module(:fake, module_config_class)
      config = configuration_class.new

      expect(config.fake).to be_a(module_config_class)
      expect(config.fake).to equal(config.fake)
    end

    it "does not leak registrations to the parent class" do
      configuration_class.register_module(:fake, module_config_class)

      expect(described_class.registered_modules).not_to have_key(:fake)
    end
  end

  describe "unknown module access" do
    it "raises with the registered modules listed" do
      configuration_class.register_module(:fake, module_config_class)

      expect { configuration_class.new.securty }
        .to raise_error(Forseti::ConfigurationError, /Unknown Forseti module or setting `securty`.*fake/)
    end
  end

  describe "#validate!" do
    it "delegates to every touched module configuration" do
      configuration_class.register_module(:fake, module_config_class)
      config = configuration_class.new
      allow(config.fake.enable!).to receive(:validate!)

      config.validate!

      expect(config.fake).to have_received(:validate!)
    end

    it "returns true when nothing has been touched" do
      expect(configuration_class.new.validate!).to be(true)
    end
  end
end
