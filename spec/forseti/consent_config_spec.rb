# frozen_string_literal: true

RSpec.describe "Consent and Retention configuration" do
  describe Forseti::Consent do
    it "is registered lazily as Forseti.config.consent" do
      expect(Forseti.config.consent).to be_a(Forseti::Consent::Config)
      expect(Forseti.config.consent.purposes).to eq([])
    end

    it "fails fast without Active Record, pointing at the generator" do
      expect { described_class.verify! }
        .to raise_error(Forseti::Error, /requires Active Record.*forseti:consent/m)
    end

    it "refuses to record consent without Active Record rather than dropping it" do
      expect { described_class.grant(Object.new, :marketing) }
        .to raise_error(Forseti::Error, /requires Active Record/)
    end
  end

  describe Forseti::Retention::Config do
    it "is registered lazily as Forseti.config.retention" do
      expect(Forseti.config.retention).to be_a(described_class)
      expect(Forseti.config.retention.policies).to eq([])
    end

    it "declares validated policies and marks the module enabled" do
      policy = Forseti.config.retention.policy(:old_events, model: "Forseti::AuditEvent",
                                                            keep_for: 2.years, timestamp: :occurred_at,
                                                            strategy: :delete)

      expect(policy.keep_for).to eq(2.years)
      expect(Forseti.config.retention.policies.map(&:name)).to eq([:old_events])
      expect(Forseti.config.retention.enabled?).to be(true)
    end

    it "rejects duplicate names, bad strategies, and non-durations" do
      retention = Forseti.config.retention
      retention.policy(:dup, model: "User", keep_for: 1.year)

      expect { retention.policy(:dup, model: "User", keep_for: 1.year) }
        .to raise_error(Forseti::ConfigurationError, /declared twice/)
      expect { retention.policy(:bad, model: "User", keep_for: 1.year, strategy: :truncate) }
        .to raise_error(Forseti::ConfigurationError, /unknown strategy/)
      expect { retention.policy(:worse, model: "User", keep_for: "forever") }
        .to raise_error(Forseti::ConfigurationError, /must be a duration/)
    end
  end

  describe "consent.storage scanner check" do
    it "does not apply while the module is disabled" do
      expect(Forseti::Scanner::Checks::ConsentStorage.new(fake_context).applies?).to be(false)
    end

    it "fails when enabled without Active Record" do
      Forseti.config.consent.enable!

      result = Forseti::Scanner::Checks::ConsentStorage.new(fake_context).call

      expect(result).to be_failed
    end
  end
end
