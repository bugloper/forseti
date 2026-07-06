# frozen_string_literal: true

RSpec.describe Forseti::Privacy::LogRedactor do
  let(:plain_formatter) { ->(_severity, _time, _progname, message) { "#{message}\n" } }
  let(:redactor) { described_class.new(plain_formatter) }

  def format_line(message)
    redactor.call("INFO", Time.now.utc, nil, message)
  end

  context "with log_redaction_mode :enforce" do
    before { Forseti.config.privacy.log_redaction_mode = :enforce }

    it "redacts emails, cards, and SSNs by default" do
      line = format_line("receipt to jane@example.com card 4242 4242 4242 4242 ssn 123-45-6789")

      expect(line).to include("[REDACTED:email]", "[REDACTED:credit_card]", "[REDACTED:ssn]")
      expect(line).not_to include("jane@example.com", "4242", "123-45-6789")
    end

    it "leaves Luhn-invalid digit runs untouched" do
      expect(format_line("order 4242424242424241 confirmed")).to include("4242424242424241")
    end

    it "leaves clean lines untouched" do
      expect(format_line("Completed 200 OK in 12ms")).to eq("Completed 200 OK in 12ms\n")
    end

    it "only scans configured redact_types" do
      Forseti.config.privacy.redact_types = %i[ssn]

      expect(format_line("mail jane@example.com")).to include("jane@example.com")
    end

    it "ignores unknown and key-only types in redact_types" do
      Forseti.config.privacy.redact_types = %i[password nonexistent email]

      expect(format_line("mail jane@example.com")).to include("[REDACTED:email]")
    end

    it "instruments detections without leaking values" do
      payloads = []
      subscription = ActiveSupport::Notifications.subscribe(described_class::EVENT) do |event|
        payloads << event.payload
      end

      format_line("mail jane@example.com")

      expect(payloads).to eq([{ types: [:email], source: :log }])
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end
  end

  context "with log_redaction_mode :report" do
    before { Forseti.config.privacy.log_redaction_mode = :report }

    it "leaves the line untouched but instruments the detection" do
      detected = []
      subscription = ActiveSupport::Notifications.subscribe(described_class::EVENT) do |event|
        detected.concat(event.payload[:types])
      end

      line = format_line("mail jane@example.com ssn 123-45-6789")

      expect(line).to include("jane@example.com", "123-45-6789")
      expect(detected).to contain_exactly(:email, :ssn)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end
  end

  describe "fail-open behavior" do
    before { Forseti.config.privacy.log_redaction_mode = :enforce }

    it "returns the formatted line when redaction itself blows up" do
      allow(Forseti::PII).to receive(:[]).and_raise("registry exploded")

      expect(format_line("mail jane@example.com")).to eq("mail jane@example.com\n")
    end

    it "passes non-string formatter output through" do
      weird_formatter = ->(*) { :not_a_string }

      expect(described_class.new(weird_formatter).call("INFO", Time.now.utc, nil, "x")).to eq(:not_a_string)
    end
  end

  describe ".install" do
    it "wraps the formatter exactly once" do
      logger = Logger.new(IO::NULL)
      described_class.install(logger)
      described_class.install(logger)

      expect(logger.formatter).to be_a(described_class)
      expect(logger.formatter.instance_variable_get(:@formatter)).not_to be_a(described_class)
    end

    it "redacts through a real logger end to end" do
      Forseti.config.privacy.log_redaction_mode = :enforce
      io = StringIO.new
      logger = Logger.new(io)
      described_class.install(logger)

      logger.info("charge for jane@example.com")

      expect(io.string).to include("[REDACTED:email]")
      expect(io.string).not_to include("jane@example.com")
    end
  end
end
