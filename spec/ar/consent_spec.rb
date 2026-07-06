# frozen_string_literal: true

RSpec.describe "Consent (Active Record)" do
  let(:user) { User.create!(name: "jane") }

  before do
    Forseti::ConsentRecord.delete_all
    Forseti::AuditEvent.delete_all
  end

  after { Forseti::Audit::Current.reset }

  describe "grant / withdraw / granted?" do
    it "tracks current state through the append-only history" do
      expect(Forseti::Consent.granted?(user, :marketing)).to be(false)

      Forseti::Consent.grant(user, :marketing, policy_version: "2026-03")
      expect(Forseti::Consent.granted?(user, :marketing)).to be(true)

      Forseti::Consent.withdraw(user, :marketing)
      expect(Forseti::Consent.granted?(user, :marketing)).to be(false)

      # Every state change is preserved — that history is the evidence.
      expect(Forseti::Consent.history(user, :marketing).map(&:action)).to eq(%w[withdrawn granted])
    end

    it "answers version-specific queries — the re-consent trigger" do
      Forseti::Consent.grant(user, :marketing, policy_version: "2026-03")

      expect(Forseti::Consent.granted?(user, :marketing, policy_version: "2026-03")).to be(true)
      expect(Forseti::Consent.granted?(user, :marketing, policy_version: "2026-04")).to be(false)
    end

    it "keeps purposes independent" do
      Forseti::Consent.grant(user, :marketing)

      expect(Forseti::Consent.granted?(user, :analytics)).to be(false)
      expect(Forseti::Consent.history(user).map(&:purpose)).to eq(%w[marketing])
    end

    it "captures the ambient request context on the record" do
      Forseti::Audit::Current.ip_address = "10.0.0.9"

      record = Forseti::Consent.grant(user, :marketing)

      expect(record.ip_address).to eq("10.0.0.9")
    end

    it "validates declared purposes" do
      Forseti.config.consent.purposes = %i[marketing]

      expect { Forseti::Consent.grant(user, :marketting) }
        .to raise_error(Forseti::ConfigurationError, /Unknown consent purpose :marketting.*marketing/m)
    end

    it "emits audit events when the audit module is on" do
      Forseti.config.audit.enable!
      Forseti.config.audit.sinks = [:active_record]

      Forseti::Consent.grant(user, :marketing, policy_version: "2026-03")
      Forseti::Consent.withdraw(user, :marketing)

      actions = Forseti::AuditEvent.order(:id).pluck(:action)
      expect(actions).to eq(%w[consent_granted consent_withdrawn])
      expect(Forseti::AuditEvent.first.metadata).to include("purpose" => "marketing")
    end
  end

  describe Forseti::ConsentRecord do
    it "is append-only: updates and destroys raise" do
      record = Forseti::Consent.grant(user, :marketing)

      expect { record.update!(action: "withdrawn") }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { record.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "only accepts known actions" do
      record = described_class.new(subject: user, purpose: "x", action: "maybe")

      expect(record.valid?).to be(false)
      expect(record.errors.attribute_names).to include(:action)
    end
  end

  describe "consent.storage scanner check" do
    it "passes when enabled with the table present" do
      Forseti.config.consent.enable!

      result = Forseti::Scanner::Checks::ConsentStorage.new(fake_context).call

      expect(result).to be_passed
    end
  end
end
