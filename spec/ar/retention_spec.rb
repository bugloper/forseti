# frozen_string_literal: true

RSpec.describe "Retention (Active Record)" do
  before do
    User.delete_all
    Forseti::AuditEvent.delete_all
  end

  def create_user(name:, created_at:)
    User.create!(name: name, created_at: created_at)
  end

  describe "preview and run with the :destroy strategy" do
    before do
      Forseti.config.retention.policy(:stale_users, model: "User", keep_for: 1.year)
      create_user(name: "old", created_at: 2.years.ago)
      create_user(name: "new", created_at: 1.day.ago)
    end

    it "previews eligible counts without deleting" do
      expect(Forseti::Retention.preview).to eq([{ policy: :stale_users, eligible: 1 }])
      expect(User.count).to eq(2)
    end

    it "prunes only past-horizon records" do
      expect(Forseti::Retention.run).to eq([{ policy: :stale_users, deleted: 1 }])
      expect(User.pluck(:name)).to eq(["new"])
    end

    it "audits every prune with the count" do
      Forseti.config.audit.enable!
      Forseti.config.audit.sinks = [:active_record]

      Forseti::Retention.run

      event = Forseti::AuditEvent.where(action: "retention_pruned").sole
      expect(event.metadata).to eq("policy" => "stale_users", "deleted" => 1)
      expect(event.actor_type).to eq("system")
    end
  end

  describe "scopes" do
    it "only touches records the scope selects" do
      Forseti.config.retention.policy(:deactivated_users, model: "User", keep_for: 30.days,
                                                          scope: ->(users) { users.where.not(deactivated_at: nil) })
      User.create!(name: "active-old", created_at: 1.year.ago)
      User.create!(name: "gone-old", created_at: 1.year.ago, deactivated_at: 6.months.ago)

      Forseti::Retention.run

      expect(User.pluck(:name)).to eq(["active-old"])
    end
  end

  describe "the :delete strategy against the readonly audit trail" do
    before do
      Forseti.config.retention.policy(:stale_audit_events, model: "Forseti::AuditEvent",
                                                           keep_for: 2.years, timestamp: :occurred_at,
                                                           strategy: :delete)
      Forseti::AuditEvent.create!(action: "old", occurred_at: 3.years.ago)
      Forseti::AuditEvent.create!(action: "recent", occurred_at: 1.day.ago)
    end

    it "prunes through delete_all — the deliberate path past readonly?" do
      expect(Forseti::Retention.run).to eq([{ policy: :stale_audit_events, deleted: 1 }])
      expect(Forseti::AuditEvent.pluck(:action)).to eq(["recent"])
    end

    it "would raise with :destroy, forcing the choice consciously" do
      policy = Forseti::Retention::Policy.new(name: :wrong, model: "Forseti::AuditEvent",
                                              keep_for: 2.years, timestamp: :occurred_at)

      expect { policy.prune! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe "error isolation" do
    it "reports a broken policy and still runs the others" do
      Forseti.config.retention.policy(:broken, model: "NoSuchModel", keep_for: 1.year)
      Forseti.config.retention.policy(:working, model: "User", keep_for: 1.year)
      create_user(name: "old", created_at: 2.years.ago)
      allow(Rails.error).to receive(:report)

      results = Forseti::Retention.run

      expect(results.first[:error]).to include("NameError")
      expect(results.last).to eq(policy: :working, deleted: 1)
      expect(Rails.error).to have_received(:report).once
    end
  end
end
