# frozen_string_literal: true

RSpec.describe Forseti::Compliance::TTYFormatter do
  let(:policy) do
    Forseti::Compliance::Policy.define(:test, name: "Test Policy", version: "1.0") do |p|
      p.requirement :good, title: "Verified thing", article: "Art. 1",
                           verify: -> { true }, evidence: "flag"
      p.requirement :attested, title: "Attested thing", article: "Art. 2"
      p.requirement :bad, title: "Broken thing", article: "Art. 3",
                          verify: -> { false }, evidence: "flag", remediation: "Fix the flag."
      p.requirement :unknown, title: "Unknowable thing", article: "Art. 4",
                              verify: -> { raise }, evidence: "flag"
    end
  end

  let(:output) do
    attestations = Forseti::Compliance::Attestations.new(
      "test" => { "attested" => { "attested_by" => "jane@corp.com",
                                  "attested_on" => Date.new(2026, 7, 1) } }
    )
    result = Forseti::Compliance::Evaluator.new(policy, context: fake_context,
                                                        attestations: attestations).evaluate
    described_class.new([result], color: false).render
  end

  it "renders verified, attested, unmet, and unverified distinctly" do
    expect(output).to include("✔ Art. 1", "[verified]")
    expect(output).to include("✔ Art. 2", "[attested by jane@corp.com on 2026-07-01]")
    expect(output).to include("✖ Art. 3", "[unmet]", "↳ Fix the flag.")
    expect(output).to include("? Art. 4", "[unverified]")
  end

  it "renders the score line and always carries the disclaimer" do
    expect(output).to include("Compliance:", "2 met, 1 unmet, 1 unverified")
    expect(output).to include(Forseti::Compliance::DISCLAIMER)
  end
end
