# frozen_string_literal: true

RSpec.describe Forseti::Compliance do
  describe ".registry" do
    it "ships gdpr, ccpa, lgpd, and dpdp" do
      expect(described_class.registry.keys).to contain_exactly(:gdpr, :ccpa, :lgpd, :dpdp)
    end
  end

  describe "built-in policy consistency" do
    it "gives every requirement a title and an article" do
      described_class.registry.each_value do |policy|
        policy.requirements.each do |requirement|
          expect(requirement.title).to be_present, "#{policy.key}/#{requirement.key} lacks a title"
          expect(requirement.article).to be_present, "#{policy.key}/#{requirement.key} lacks an article"
        end
      end
    end

    it "only references scanner checks that actually exist" do
      described_class.registry.each_value do |policy|
        policy.requirements.flat_map(&:checks).each do |check_id|
          expect(Forseti::Scanner.registry[check_id])
            .not_to be_nil, "#{policy.key} references unknown check #{check_id}"
        end
      end
    end

    it "mixes checkable and attestable requirements in every policy" do
      described_class.registry.each_value do |policy|
        kinds = policy.requirements.map(&:kind).uniq
        expect(kinds).to contain_exactly(:checkable, :attestable)
      end
    end

    it "gives GDPR reference-implementation depth" do
      expect(described_class.fetch(:gdpr).requirements.size).to be >= 10
    end
  end

  describe ".define_policy" do
    it "registers a custom policy usable like the built-ins" do
      described_class.define_policy(:acme, name: "ACME Baseline", version: "2026.1") do |p|
        p.requirement :sso, title: "Admin behind SSO", article: "SEC-4"
      end

      expect(described_class.fetch(:acme).requirements.map(&:key)).to eq([:sso])
      expect { Forseti.config.compliance.enable(:acme) }.not_to raise_error
    end

    it "rejects duplicate policy keys" do
      expect do
        described_class.define_policy(:gdpr, name: "x", version: "1") do |p|
          p.requirement :never_reached, title: "x", article: "1"
        end
      end.to raise_error(Forseti::Error, /already registered/)
    end

    it "rejects duplicate requirement keys" do
      expect do
        described_class.define_policy(:dup_req, name: "x", version: "1") do |p|
          p.requirement :a, title: "A", article: "1"
          p.requirement :a, title: "A again", article: "2"
        end
      end.to raise_error(Forseti::Error, /declared twice/)
    end

    it "freezes policies against later mutation" do
      expect { described_class.fetch(:gdpr).requirement(:sneaky, title: "x", article: "y") }
        .to raise_error(FrozenError)
    end
  end

  describe "requirement DSL" do
    it "derives the kind from checks/verify presence" do
      policy = described_class.define_policy(:kinds, name: "K", version: "1") do |p|
        p.requirement :a, title: "A", article: "1", checks: %w[security.csp]
        p.requirement :b, title: "B", article: "2", verify: -> { true }, evidence: "true"
        p.requirement :c, title: "C", article: "3"
      end

      expect(policy[:a].kind).to eq(:checkable)
      expect(policy[:b].kind).to eq(:checkable)
      expect(policy[:c].kind).to eq(:attestable)
    end

    it "requires an evidence description alongside verify procs" do
      expect do
        described_class.define_policy(:opaque, name: "O", version: "1") do |p|
          p.requirement :a, title: "A", article: "1", verify: -> { true }
        end
      end.to raise_error(ArgumentError, /evidence/)
    end
  end

  describe "config.compliance.enable" do
    it "accumulates validated policy keys" do
      Forseti.config.compliance.enable(:gdpr)
      Forseti.config.compliance.enable(:ccpa)
      Forseti.config.compliance.enable(:gdpr)

      expect(Forseti.config.compliance.policies).to eq(%i[gdpr ccpa])
      expect(Forseti.config.compliance.enabled?).to be(true)
    end

    it "rejects unknown policies at configure time" do
      expect { Forseti.config.compliance.enable(:hipaa) }
        .to raise_error(Forseti::ConfigurationError, /Unknown compliance policy :hipaa/)
    end
  end
end
