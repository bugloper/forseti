# frozen_string_literal: true

RSpec.describe Forseti::Config::Base do
  let(:config_class) do
    Class.new(described_class) do
      setting :mode,
              default: versioned("1.0" => :report),
              values: Forseti::Config::Base::MODES,
              description: "How violations are handled."
      setting :max_age, default: 3600
      setting :strict, default: false, type: :boolean

      def self.name = "Example::Config"

      private

      def apply_recommended_defaults!
        self.mode = :enforce
      end
    end
  end
  let(:config) { config_class.new }

  describe "declared settings" do
    it "returns declared defaults until assigned" do
      expect(config.mode).to eq(:report)
      expect(config.max_age).to eq(3600)
    end

    it "stores assigned values" do
      config.max_age = 7200

      expect(config.max_age).to eq(7200)
    end

    it "rejects values outside the allowed list on assignment" do
      expect { config.mode = :yolo }
        .to raise_error(Forseti::InvalidSettingError, /`mode` must be one of :off, :report, :enforce/)
    end

    it "exposes setting metadata for introspection" do
      setting = config_class.settings.fetch(:mode)

      expect(setting.values).to eq(%i[off report enforce])
      expect(setting.description).to eq("How violations are handled.")
    end
  end

  describe "boolean settings" do
    it "defines a predicate" do
      expect(config.strict?).to be(false)

      config.strict = true
      expect(config.strict?).to be(true)
    end

    it "rejects non-boolean values" do
      expect { config.strict = "yes" }
        .to raise_error(Forseti::InvalidSettingError, /`strict` must be true or false/)
    end
  end

  describe "#enable! / #disable!" do
    it "starts disabled" do
      expect(config.enabled?).to be(false)
    end

    it "enables the module and applies its recommended defaults" do
      config.enable!

      expect(config.enabled?).to be(true)
      expect(config.mode).to eq(:enforce)
    end

    it "keeps explicit choices adjustable after enable!" do
      config.enable!
      config.mode = :report

      expect(config.mode).to eq(:report)
    end

    it "disables the module" do
      expect(config.enable!.disable!.enabled?).to be(false)
    end
  end

  describe "unknown settings" do
    it "raises on unknown reads with the available settings listed" do
      expect { config.mod }
        .to raise_error(Forseti::UnknownSettingError, /Unknown setting `mod` for Example::Config.*enabled.*mode/)
    end

    it "raises on unknown writes without the trailing =" do
      expect { config.modee = :report }
        .to raise_error(Forseti::UnknownSettingError, /Unknown setting `modee`/)
    end
  end

  describe "versioned defaults resolution" do
    it "resolves against the root configuration's pinned defaults version" do
      stub_const("Forseti::Configuration::KNOWN_DEFAULTS_VERSIONS", %w[1.0 1.1].freeze)
      klass = Class.new(described_class) do
        setting :mode, default: versioned("1.0" => :report, "1.1" => :enforce)
      end
      root = Forseti::Configuration.new

      expect(klass.new(root).mode).to eq(:report)

      root.defaults = "1.1"
      expect(klass.new(root).mode).to eq(:enforce)
    end
  end

  describe "inheritance" do
    it "gives subclasses their parents' settings without sharing the registry" do
      subclass = Class.new(config_class) { setting :extra, default: nil }

      expect(subclass.settings).to include(:mode, :extra)
      expect(config_class.settings).not_to include(:extra)
    end
  end

  describe "#validate!" do
    it "returns true for valid assigned values" do
      config.mode = :off

      expect(config.validate!).to be(true)
    end
  end
end
