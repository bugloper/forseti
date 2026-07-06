# frozen_string_literal: true

RSpec.describe Forseti::Scanner do
  describe "components" do
    describe Forseti::Scanner::Severity do
      it "orders severities" do
        expect(described_class.at_least?(:critical, :high)).to be(true)
        expect(described_class.at_least?(:low, :high)).to be(false)
        expect(described_class.at_least?(:high, :high)).to be(true)
      end

      it "rejects unknown severities" do
        expect { described_class.validate!(:catastrophic) }.to raise_error(ArgumentError, /catastrophic/)
      end
    end

    describe Forseti::Scanner::Check do
      it "exposes declared metadata" do
        check = build_check(check_id: "custom.example", severity: :high)

        expect(check.id).to eq("custom.example")
        expect(check.severity).to eq(:high)
        expect(check.category).to eq("custom")
        expect(check.production_only?).to be(false)
      end

      it "rejects invalid severities at declaration time" do
        expect { build_check(check_id: "custom.bad", severity: :nope) }.to raise_error(ArgumentError)
      end

      it "requires #call to be implemented" do
        check = build_check(check_id: "custom.abstract")

        expect { check.new(fake_context).call }.to raise_error(NotImplementedError)
      end
    end

    describe Forseti::Scanner::Result do
      let(:check) { build_check(check_id: "custom.result", severity: :high) }

      it "rejects unknown statuses" do
        expect { described_class.new(check: check, status: :maybe) }.to raise_error(ArgumentError)
      end

      it "treats only passed and failed as scoreable" do
        expect(described_class.new(check: check, status: :passed)).to be_scoreable
        expect(described_class.new(check: check, status: :failed)).to be_scoreable
        expect(described_class.new(check: check, status: :skipped)).not_to be_scoreable
        expect(described_class.errored(check, RuntimeError.new("boom"))).not_to be_scoreable
      end

      it "includes remediation in to_h only for failures" do
        failed = described_class.new(check: check, status: :failed, message: "bad")
        passed = described_class.new(check: check, status: :passed, message: "ok")

        expect(failed.to_h[:remediation]).to eq("Fix it.")
        expect(passed.to_h).not_to have_key(:remediation)
      end
    end

    describe Forseti::Scanner::Registry do
      let(:registry) { described_class.new }
      let(:check) { build_check(check_id: "custom.one") }

      it "registers and looks up checks sorted by id" do
        registry.register(build_check(check_id: "custom.b"))
        registry.register(build_check(check_id: "custom.a"))

        expect(registry.checks.map(&:id)).to eq(%w[custom.a custom.b])
      end

      it "rejects duplicates, non-checks, and missing metadata" do
        registry.register(check)

        expect { registry.register(check) }.to raise_error(Forseti::Error, /already registered/)
        expect { registry.register(String) }.to raise_error(Forseti::Error, /not a Forseti::Scanner::Check/)
        expect { registry.register(Class.new(Forseti::Scanner::Check)) }
          .to raise_error(Forseti::Error, /no id/)
      end

      it "unregisters by id" do
        registry.register(check)
        registry.unregister("custom.one")

        expect(registry.include?("custom.one")).to be(false)
      end
    end

    describe Forseti::Scanner::Runner do
      def run(checks, env: "production", scanner_config: Forseti.config.scanner)
        described_class.new(checks, context: fake_context(env: env), config: scanner_config).run
      end

      it "isolates crashing checks as :error results" do
        boom = build_check(check_id: "custom.boom") { raise "kaput" }
        fine = build_check(check_id: "custom.fine") { pass("ok") }

        results = run([boom, fine])

        expect(results.map(&:status)).to eq(%i[error passed])
        expect(results.first.message).to include("kaput")
      end

      it "skips production-only checks outside production-like envs, marked :environment" do
        check = build_check(check_id: "custom.prod", production_only: true) { pass("ok") }
        result = run([check], env: "development").first

        expect(result).to be_skipped
        expect(result.skip_cause).to eq(:environment)
        expect(run([check], env: "staging").first).to be_passed
      end

      it "skips checks that do not apply, marked :not_applicable" do
        check = build_check(check_id: "custom.na", applies: false) { pass("ok") }
        result = run([check]).first

        expect(result).to be_skipped
        expect(result.skip_cause).to eq(:not_applicable)
      end

      it "skips checks listed in scanner.skip_checks, marked :config" do
        check = build_check(check_id: "custom.skipme") { pass("ok") }
        Forseti.config.scanner.skip_checks = ["custom.skipme"]

        result = run([check]).first

        expect(result).to be_skipped
        expect(result.skip_cause).to eq(:config)
        expect(result.message).to include("skip_checks")
      end
    end
  end

  describe ".run against the dummy app" do
    let(:report) { described_class.run(context: Forseti::Scanner::Context.new) }

    it "produces one result per registered check" do
      expect(report.results.size).to eq(described_class.registry.checks.size)
    end

    it "finds the dummy app's known weaknesses" do
      expect(report.failed.map(&:id)).to contain_exactly("privacy.filter_parameters", "security.csp")
    end

    it "passes the posture the dummy app gets from load_defaults" do
      expect(report.passed.map(&:id)).to include(
        "security.load_defaults", "security.csrf", "security.open_redirects",
        "security.default_headers", "security.cookies"
      )
    end

    it "skips production-only checks in the test environment" do
      expect(report.skipped.map(&:id)).to include(
        "security.force_ssl", "security.hsts", "security.host_authorization", "privacy.log_level"
      )
    end

    it "never crashes a check" do
      expect(report.errored).to be_empty
    end
  end

  describe ".register" do
    it "adds custom checks to subsequent runs" do
      check = build_check(check_id: "custom.mine") { pass("ok") }
      described_class.register(check)

      report = described_class.run(context: fake_context)

      expect(report.results.map(&:id)).to include("custom.mine")
    end
  end
end
