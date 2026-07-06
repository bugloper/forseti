# frozen_string_literal: true

RSpec.describe Forseti::PII do
  describe ".detect_key" do
    it "normalizes separators and case so word boundaries work" do
      expect(described_class.detect_key("User_SSN").map(&:key)).to include(:ssn)
      expect(described_class.detect_key(:customer_email).map(&:key)).to include(:email)
      expect(described_class.detect_key("dateOfBirth")).to be_empty # camelCase isn't split; documented
      expect(described_class.detect_key("date_of_birth").map(&:key)).to include(:date_of_birth)
    end

    it "does not match unrelated names" do
      expect(described_class.detect_key("session_count")).to be_empty
      expect(described_class.detect_key("description")).to be_empty
    end

    it "matches credential-ish names as api_credentials" do
      %w[api_key access_key client_secret refresh_token].each do |name|
        expect(described_class.detect_key(name).map(&:key)).to include(:api_credentials)
      end
    end
  end

  describe ".detect_value" do
    it "detects emails" do
      expect(described_class.detect_value("contact jane@example.com now").map(&:key)).to include(:email)
    end

    it "detects Luhn-valid card numbers and rejects Luhn-invalid ones" do
      expect(described_class.detect_value("card 4242 4242 4242 4242").map(&:key)).to include(:credit_card)
      expect(described_class.detect_value("id 4242424242424241").map(&:key)).not_to include(:credit_card)
    end

    it "detects dashed SSNs only" do
      expect(described_class.detect_value("ssn 123-45-6789").map(&:key)).to include(:ssn)
      expect(described_class.detect_value("ref 123456789").map(&:key)).not_to include(:ssn)
    end

    it "detects mod-97-valid IBANs and rejects invalid ones" do
      expect(described_class.detect_value("pay DE89 3704 0044 0532 0130 00").map(&:key)).to include(:iban)
      expect(described_class.detect_value("code DE89370400440532013001").map(&:key)).not_to include(:iban)
    end

    it "validates IPv4 octets" do
      expect(described_class.detect_value("from 192.168.1.10").map(&:key)).to include(:ip_address)
      expect(described_class.detect_value("v 999.999.999.999").map(&:key)).not_to include(:ip_address)
    end

    it "never matches non-strings" do
      expect(described_class.detect_value(42)).to be_empty
      expect(described_class.detect_value(nil)).to be_empty
    end
  end

  describe ".register" do
    it "adds an app-defined type visible to every consumer" do
      described_class.register(:employee_badge,
                               sensitivity: :medium,
                               key_patterns: [/badge (number|id)/],
                               filter_keys: %i[badge_number],
                               probes: %w[badge_number])

      expect(described_class.detect_key("badge_number").map(&:key)).to include(:employee_badge)
      expect(described_class.filter_keys).to include(:badge_number)
      expect(described_class.probe_keys).to include("badge_number")
    end

    it "rejects duplicate keys and unknown sensitivities" do
      expect { described_class.register(:email, sensitivity: :high) }
        .to raise_error(Forseti::Error, /already registered/)
      expect { described_class.register(:odd, sensitivity: :radioactive) }
        .to raise_error(ArgumentError, /radioactive/)
    end
  end

  describe ".filter_keys" do
    it "unions the recommended filter keys of every type" do
      expect(described_class.filter_keys)
        .to include(:passw, :email, :card_number, :cvv, :ssn, :iban, :token, :passport)
    end
  end

  it "classifies sensitivity per type" do
    expect(described_class[:credit_card].sensitivity).to eq(:critical)
    expect(described_class[:email].sensitivity).to eq(:high)
    expect(described_class[:ip_address].sensitivity).to eq(:medium)
  end
end
