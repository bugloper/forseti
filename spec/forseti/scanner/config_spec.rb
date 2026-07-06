# frozen_string_literal: true

RSpec.describe Forseti::Scanner::Config do
  it "is registered lazily as Forseti.config.scanner" do
    expect(Forseti.config.scanner).to be_a(described_class)
  end

  it "defaults to skipping nothing and failing on :high" do
    config = Forseti.config.scanner

    expect(config.skip_checks).to eq([])
    expect(config.fail_on).to eq(:high)
  end

  it "validates fail_on" do
    expect { Forseti.config.scanner.fail_on = :sometimes }
      .to raise_error(Forseti::InvalidSettingError, /fail_on/)
    expect { Forseti.config.scanner.fail_on = :none }.not_to raise_error
  end
end
