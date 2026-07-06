# frozen_string_literal: true

RSpec.describe Forseti::Config::VersionedDefault do
  subject(:versioned) { described_class.new("1.0" => :report, "1.2" => :enforce) }

  it "resolves an exact version match" do
    expect(versioned.resolve("1.0")).to eq(:report)
    expect(versioned.resolve("1.2")).to eq(:enforce)
  end

  it "resolves to the newest entry not newer than the pin" do
    expect(versioned.resolve("1.1")).to eq(:report)
    expect(versioned.resolve("3.0")).to eq(:enforce)
  end

  it "raises when the pin predates every entry" do
    expect { versioned.resolve("0.9") }
      .to raise_error(Forseti::ConfigurationError, /No default declared for defaults version "0\.9"/)
  end

  it "rejects an empty version map" do
    expect { described_class.new({}) }.to raise_error(ArgumentError)
  end
end
