# frozen_string_literal: true

RSpec.describe "Audit persistence (Active Record)" do
  before do
    Forseti.config.audit.enable!
    Forseti::AuditEvent.delete_all
  end

  after { Forseti::Audit::Current.reset }

  describe Forseti::AuditEvent do
    let(:event_row) do
      described_class.create!(action: "role_changed", occurred_at: Time.current,
                              metadata: { "from" => "member" })
    end

    it "is append-only: updates and destroys raise" do
      expect { event_row.update!(action: "tampered") }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { event_row.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(event_row.reload.action).to eq("role_changed")
    end

    it "requires action and occurred_at" do
      record = described_class.new

      expect(record.valid?).to be(false)
      expect(record.errors.attribute_names).to include(:action, :occurred_at)
    end

    it "resolves polymorphic actors" do
      user = User.create!(name: "jane")
      row = described_class.create!(action: "login_succeeded", occurred_at: Time.current,
                                    actor: user)

      expect(row.reload.actor).to eq(user)
    end
  end

  describe "the :active_record sink end to end" do
    it "persists a recorded event with filtered metadata" do
      Forseti.config.audit.sinks = [:active_record]
      user = User.create!(name: "jane")

      Forseti::Audit.record(:data_exported, actor: user,
                                            metadata: { email: "a@b.com", format: "csv" },
                                            request: nil)

      row = Forseti::AuditEvent.last
      expect(row.action).to eq("data_exported")
      expect(row.actor).to eq(user)
      expect(row.metadata).to eq("email" => "[FILTERED]", "format" => "csv")
      expect(row.occurred_at).to be_present
    end

    it "verifies cleanly when Active Record is loaded" do
      Forseti.config.audit.sinks = [:active_record]

      expect { Forseti::Audit.verify_sinks! }.not_to raise_error
    end
  end

  describe "audit.storage scanner check" do
    it "passes when the table exists" do
      Forseti.config.audit.sinks = [:active_record]
      result = Forseti::Scanner::Checks::AuditStorage.new(fake_context).call

      expect(result).to be_passed
    end

    it "fails when the table is missing" do
      Forseti.config.audit.sinks = [:active_record]
      allow(Forseti::AuditEvent).to receive(:table_exists?).and_return(false)

      result = Forseti::Scanner::Checks::AuditStorage.new(fake_context).call

      expect(result).to be_failed
      expect(result.message).to include("missing")
    end
  end
end
