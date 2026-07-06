# frozen_string_literal: true

RSpec.describe Forseti::Audit do
  let(:written) { [] }
  let(:capture_sink) do
    events = written
    Class.new { define_method(:write) { |event| events << event } }.new
  end

  before do
    stub_const("FakeUser", Struct.new(:id))
    Forseti.config.audit.enable!
    Forseti.config.audit.sinks = [capture_sink]
  end

  after { Forseti::Audit::Current.reset }

  describe ".record" do
    it "is a no-op when the module is disabled" do
      Forseti.config.audit.disable!

      expect(described_class.record(:login_succeeded)).to be_nil
      expect(written).to be_empty
    end

    it "builds an immutable event and dispatches it to every sink" do
      actor = FakeUser.new(42)
      event = described_class.record(:role_changed, actor: actor, subject: :system,
                                                    metadata: { from: "member" })

      expect(written).to eq([event])
      expect(event).to be_frozen
      expect(event.to_h).to include(action: "role_changed", actor_type: "FakeUser", actor_id: 42,
                                    subject_type: "system", subject_id: nil)
    end

    it "filters PII out of metadata before dispatch" do
      event = described_class.record(:signup, metadata: { email: "a@b.com", password: "x", plan: "pro" })

      expect(event.metadata).to eq(email: "[FILTERED]", password: "[FILTERED]", plan: "pro")
    end

    it "uses the ambient Current context" do
      Forseti::Audit::Current.actor = FakeUser.new(7)
      Forseti::Audit::Current.ip_address = "10.0.0.1"
      Forseti::Audit::Current.request_id = "req-1"

      event = described_class.record(:data_exported)

      expect(event.actor_id).to eq(7)
      expect(event.ip_address).to eq("10.0.0.1")
      expect(event.request_id).to eq("req-1")
    end

    it "lets explicit arguments beat the ambient context, including actor: nil" do
      Forseti::Audit::Current.actor = FakeUser.new(7)

      event = described_class.record(:retention_pruned, actor: nil)

      expect(event.actor_type).to be_nil
      expect(event.actor_id).to be_nil
    end

    it "instruments audit.forseti for app subscribers" do
      seen = []
      subscription = ActiveSupport::Notifications.subscribe(described_class::EVENT) do |event|
        seen << event.payload[:event].action
      end

      described_class.record(:login_failed)

      expect(seen).to eq(["login_failed"])
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end
  end

  describe "sink error handling" do
    let(:exploding_sink) do
      Class.new { def write(_event) = raise "sink down" }.new
    end

    it "reports and continues by default, still writing later sinks" do
      Forseti.config.audit.sinks = [exploding_sink, capture_sink]
      allow(Rails.error).to receive(:report)

      described_class.record(:login_succeeded)

      expect(Rails.error).to have_received(:report).once
      expect(written.size).to eq(1)
    end

    it "raises when on_sink_error is :raise" do
      Forseti.config.audit.sinks = [exploding_sink]
      Forseti.config.audit.on_sink_error = :raise

      expect { described_class.record(:login_succeeded) }.to raise_error("sink down")
    end
  end

  describe "sink resolution" do
    it "rejects unknown symbols and objects without #write" do
      Forseti.config.audit.sinks = [:kafka]
      expect { described_class.record(:x) }
        .to raise_error(Forseti::ConfigurationError, /Unknown audit sink :kafka/)

      Forseti.config.audit.sinks = [Object.new]
      expect { described_class.record(:x) }
        .to raise_error(Forseti::ConfigurationError, /must respond to #write/)
    end

    it "writes single-line JSON through the :logger sink" do
      io = StringIO.new
      Forseti.config.audit.sinks = [Forseti::Audit::Sinks::Logger.new(Logger.new(io))]

      described_class.record(:data_exported, metadata: { format: "csv" })

      payload = JSON.parse(io.string[/\{.*\}/])["forseti_audit"]
      expect(payload["action"]).to eq("data_exported")
      expect(payload["metadata"]).to eq("format" => "csv")
    end
  end

  describe ".verify_sinks!" do
    it "fails fast when :active_record is configured without Active Record" do
      Forseti.config.audit.sinks = [:active_record]

      expect { described_class.verify_sinks! }
        .to raise_error(Forseti::Error, /requires Active Record/)
    end

    it "accepts sinks without a verify! hook" do
      expect { described_class.verify_sinks! }.not_to raise_error
    end
  end

  describe "audit.storage scanner check" do
    it "does not apply while the module is disabled" do
      Forseti.config.audit.disable!
      check = Forseti::Scanner::Checks::AuditStorage.new(fake_context)

      expect(check.applies?).to be(false)
    end

    it "fails when the :active_record sink is configured but AR is absent" do
      Forseti.config.audit.sinks = [:active_record]
      result = Forseti::Scanner::Checks::AuditStorage.new(fake_context).call

      expect(result).to be_failed
    end
  end
end
