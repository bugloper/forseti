# frozen_string_literal: true

RSpec.describe Forseti::Reporting do
  def result_for(check_id, severity, status)
    Forseti::Scanner::Result.new(
      check: build_check(check_id: check_id, severity: severity), status: status,
      message: status.to_s
    )
  end

  describe Forseti::Reporting::Score do
    it "is 100 with everything passing" do
      score = described_class.new([result_for("security.a", :critical, :passed)])

      expect(score.value).to eq(100)
      expect(score.grade).to eq("A")
    end

    it "is 100 when nothing was scoreable" do
      score = described_class.new([result_for("security.a", :critical, :skipped)])

      expect(score.value).to eq(100)
    end

    it "weights failures by severity" do
      results = [
        result_for("security.a", :critical, :failed), # 10
        result_for("security.b", :high, :passed)      # 6
      ]
      score = described_class.new(results)

      # 100 * (1 - 10/16)
      expect(score.value).to eq(38)
      expect(score.grade).to eq("F")
    end

    it "excludes skipped and errored checks from the denominator" do
      results = [
        result_for("security.a", :medium, :failed),
        result_for("security.b", :critical, :skipped),
        Forseti::Scanner::Result.errored(build_check(check_id: "security.c", severity: :critical),
                                         RuntimeError.new("boom"))
      ]

      expect(described_class.new(results).value).to eq(0)
    end

    it "reports per-category subscores" do
      results = [
        result_for("security.a", :medium, :passed),
        result_for("privacy.a", :medium, :failed)
      ]

      expect(described_class.new(results).by_category).to eq("security" => 100, "privacy" => 0)
    end
  end

  describe Forseti::Reporting::Report do
    let(:report) do
      described_class.new(
        [result_for("security.a", :medium, :failed), result_for("privacy.a", :high, :passed)],
        context: fake_context(env: "production")
      )
    end

    describe "#failing?" do
      it "compares the worst failure against the threshold" do
        expect(report.failing?(:medium)).to be(true)
        expect(report.failing?(:high)).to be(false)
      end

      it "is never failing at :none" do
        expect(report.failing?(:none)).to be(false)
      end
    end

    describe "#to_h" do
      it "emits the versioned schema" do
        hash = report.to_h

        expect(hash).to include(schema_version: 1, environment: "production")
        expect(hash[:summary]).to eq(passed: 1, failed: 1, skipped: 0, errors: 0)
        expect(hash[:results].size).to eq(2)
      end

      it "never includes secret values, only posture" do
        expect(report.to_h.to_s).not_to match(/secret_value|BEGIN RSA/)
      end
    end
  end

  describe Forseti::Reporting::Formatters::JSON do
    it "renders parseable JSON with the schema version" do
      report = Forseti::Reporting::Report.new([result_for("security.a", :low, :passed)],
                                              context: fake_context)
      parsed = JSON.parse(described_class.new(report).render)

      expect(parsed["schema_version"]).to eq(1)
      expect(parsed["score"]["value"]).to eq(100)
    end
  end

  describe Forseti::Reporting::Formatters::TTY do
    let(:report) do
      Forseti::Reporting::Report.new(
        [
          result_for("security.a", :high, :failed),
          result_for("security.b", :low, :passed),
          result_for("privacy.a", :low, :skipped)
        ],
        context: fake_context
      )
    end

    it "renders failures with remediation, then passes and skips" do
      output = described_class.new(report, color: false).render

      expect(output).to include("✖ security.a", "↳ Fix it.", "✔ security.b", "↷ privacy.a")
      expect(output).to match(%r{Score: \d+/100})
    end

    it "emits no ANSI codes when color is off" do
      expect(described_class.new(report, color: false).render).not_to include("\e[")
    end

    it "emits ANSI codes when color is on" do
      expect(described_class.new(report, color: true).render).to include("\e[31m")
    end
  end
end
