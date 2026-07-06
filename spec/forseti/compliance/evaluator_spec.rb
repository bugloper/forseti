# frozen_string_literal: true

RSpec.describe Forseti::Compliance::Evaluator do
  let(:empty_attestations) { Forseti::Compliance::Attestations.new({}) }

  def evaluate(policy, context: fake_context, attestations: empty_attestations)
    described_class.new(policy, context: context, attestations: attestations).evaluate
  end

  def build_policy(&)
    Forseti::Compliance::Policy.define(:test, name: "Test", version: "1", &)
  end

  describe "checkable requirements backed by scanner checks" do
    let(:policy) do
      build_policy do |p|
        p.requirement :transport, title: "T", article: "1", checks: %w[security.force_ssl]
      end
    end

    it "is met when the checks pass" do
      result = evaluate(policy).requirement_results.first

      expect(result.status).to eq(:met)
      expect(result.evidence.join).to include("security.force_ssl: passed")
    end

    it "is unmet when a check fails" do
      config = fake_config
      config.force_ssl = false

      result = evaluate(policy, context: fake_context(config: config)).requirement_results.first

      expect(result.status).to eq(:unmet)
      expect(result.evidence.join).to include("failed")
    end

    it "is unverified — never met — when checks could only be skipped" do
      result = evaluate(policy, context: fake_context(env: "development")).requirement_results.first

      expect(result.status).to eq(:unverified)
      expect(result.evidence.join).to include("production")
    end

    it "treats not-applicable checks as neutral when other evidence is conclusive" do
      # audit.storage doesn't apply with a non-database sink; the verify proc
      # still conclusively answers the requirement.
      Forseti.config.audit.enable!
      Forseti.config.audit.sinks = [:logger]
      policy = build_policy do |p|
        p.requirement :trail, title: "T", article: "1", checks: %w[audit.storage],
                              verify: -> { Forseti.config.audit.enabled? }, evidence: "audit on"
      end

      expect(evaluate(policy).requirement_results.first.status).to eq(:met)
    end

    it "stays unverified when every piece of evidence was not applicable" do
      policy = build_policy do |p|
        p.requirement :trail, title: "T", article: "1", checks: %w[audit.storage]
      end

      result = evaluate(policy).requirement_results.first

      expect(result.status).to eq(:unverified)
      expect(result.evidence.join).to include("No applicable evidence")
    end

    it "is unverified for unknown check ids" do
      policy = build_policy do |p|
        p.requirement :ghost, title: "G", article: "1", checks: %w[security.nonexistent]
      end

      result = evaluate(policy).requirement_results.first

      expect(result.status).to eq(:unverified)
      expect(result.evidence.join).to include("Unknown scanner check")
    end
  end

  describe "checkable requirements backed by verify procs" do
    it "maps truthy/falsy outcomes to met/unmet with the evidence string" do
      policy = build_policy do |p|
        p.requirement :on, title: "On", article: "1", verify: -> { true }, evidence: "flag"
        p.requirement :off, title: "Off", article: "2", verify: -> { false }, evidence: "flag"
      end

      results = evaluate(policy).requirement_results

      expect(results.map(&:status)).to eq(%i[met unmet])
      expect(results.first.evidence.join).to include("flag: satisfied")
    end

    it "is unverified when the proc raises" do
      policy = build_policy do |p|
        p.requirement :boom, title: "B", article: "1", verify: -> { raise "nope" }, evidence: "flag"
      end

      result = evaluate(policy).requirement_results.first

      expect(result.status).to eq(:unverified)
      expect(result.evidence.join).to include("could not verify")
    end

    it "combines verify and checks: any unmet wins" do
      policy = build_policy do |p|
        p.requirement :both, title: "B", article: "1", checks: %w[security.force_ssl],
                             verify: -> { false }, evidence: "flag"
      end

      expect(evaluate(policy).requirement_results.first.status).to eq(:unmet)
    end
  end

  describe "attestable requirements" do
    let(:policy) do
      build_policy { |p| p.requirement :ropa, title: "R", article: "30" }
    end

    it "is unmet without an attestation" do
      result = evaluate(policy).requirement_results.first

      expect(result.status).to eq(:unmet)
      expect(result.evidence.join).to include("No attestation")
    end

    it "is met with a valid attestation, carrying who and when" do
      attestations = Forseti::Compliance::Attestations.new(
        "test" => { "ropa" => { "attested_by" => "jane@corp.com", "attested_on" => Date.new(2026, 7, 1) } }
      )

      result = evaluate(policy, attestations: attestations).requirement_results.first

      expect(result.status).to eq(:met)
      expect(result).to be_attested
      expect(result.evidence.join).to include("jane@corp.com")
    end

    it "is unmet when the attestation expired" do
      attestations = Forseti::Compliance::Attestations.new(
        "test" => { "ropa" => { "attested_by" => "jane@corp.com",
                                "attested_on" => Date.new(2020, 1, 1),
                                "expires_on" => Date.new(2021, 1, 1) } }
      )

      result = evaluate(policy, attestations: attestations).requirement_results.first

      expect(result.status).to eq(:unmet)
      expect(result.evidence.join).to include("expired")
    end
  end

  describe "policy scoring" do
    it "scores met/(met+unmet) and excludes unverified, with the disclaimer in to_h" do
      policy = build_policy do |p|
        p.requirement :a, title: "A", article: "1", verify: -> { true }, evidence: "a"
        p.requirement :b, title: "B", article: "2", verify: -> { false }, evidence: "b"
        p.requirement :c, title: "C", article: "3", verify: -> { raise }, evidence: "c"
      end

      result = evaluate(policy)

      expect(result.score).to eq(50)
      expect(result.to_h[:summary]).to eq(met: 1, unmet: 1, unverified: 1, attested: 0)
      expect(result.to_h[:disclaimer]).to eq(Forseti::Compliance::DISCLAIMER)
    end

    it "has no score when nothing was assessable" do
      policy = build_policy do |p|
        p.requirement :a, title: "A", article: "1", verify: -> { raise }, evidence: "a"
      end

      expect(evaluate(policy).score).to be_nil
    end
  end
end
