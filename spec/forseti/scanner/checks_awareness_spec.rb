# frozen_string_literal: true

RSpec.describe "Scanner awareness of header managers" do
  let(:config) { fake_config }
  let(:context) { fake_context(config: config) }

  def run_check(check_class)
    check_class.new(context).call
  end

  describe "Forseti's own enforcement (ADR 002)" do
    it "passes default_headers when Forseti enforces them" do
      config.action_dispatch.default_headers = {}
      Forseti.config.security.headers_mode = :enforce

      result = run_check(Forseti::Scanner::Checks::DefaultHeaders)

      expect(result).to be_passed
      expect(result.message).to include("Forseti")
    end

    it "passes csp with a caveat when Forseti's baseline is report-only" do
      Forseti.config.security.csp_mode = :report

      result = run_check(Forseti::Scanner::Checks::CSP)

      expect(result).to be_passed
      expect(result.details.join).to include("report-only")
    end

    it "passes csp cleanly when Forseti's baseline enforces" do
      Forseti.config.security.csp_mode = :enforce

      expect(run_check(Forseti::Scanner::Checks::CSP)).to be_passed
    end

    it "prefers the app's own Rails CSP over Forseti's baseline in messaging" do
      config.content_security_policy = Object.new
      Forseti.config.security.csp_mode = :report

      expect(run_check(Forseti::Scanner::Checks::CSP).message).to include("CSP configured")
    end
  end

  describe "the secure_headers gem" do
    # Mirrors secure_headers 7.x: Configuration.dup returns the default config.
    def stub_secure_headers(csp:, opt_out_sentinel: :opt_out)
      configuration = Class.new do
        define_singleton_method(:dup) { Struct.new(:csp).new(csp) }
      end
      stub_const("SecureHeaders", Module.new)
      stub_const("SecureHeaders::Configuration", configuration)
      stub_const("SecureHeaders::OPT_OUT", opt_out_sentinel)
    end

    def stub_legacy_secure_headers(csp:)
      configuration = Class.new do
        define_singleton_method(:get) { Struct.new(:csp).new(csp) }
      end
      stub_const("SecureHeaders", Module.new)
      stub_const("SecureHeaders::Configuration", configuration)
    end

    it "skips default_headers with a reason" do
      stub_secure_headers(csp: "anything")
      config.action_dispatch.default_headers = {}

      result = run_check(Forseti::Scanner::Checks::DefaultHeaders)

      expect(result).to be_skipped
      expect(result.message).to include("secure_headers gem")
    end

    it "passes csp when the gem manages a policy" do
      stub_secure_headers(csp: Object.new)

      result = run_check(Forseti::Scanner::Checks::CSP)

      expect(result).to be_passed
      expect(result.message).to include("secure_headers")
    end

    it "fails csp when the gem is configured with OPT_OUT" do
      stub_secure_headers(csp: :opt_out)

      result = run_check(Forseti::Scanner::Checks::CSP)

      expect(result).to be_failed
      expect(result.message).to include("OPT_OUT")
    end

    it "passes csp via the legacy Configuration.get API" do
      stub_legacy_secure_headers(csp: Object.new)

      expect(run_check(Forseti::Scanner::Checks::CSP)).to be_passed
    end

    it "skips csp when introspection blows up" do
      stub_const("SecureHeaders", Module.new)
      stub_const("SecureHeaders::Configuration", Class.new do
        def self.get = raise "internal API changed"
      end)

      result = run_check(Forseti::Scanner::Checks::CSP)

      expect(result).to be_skipped
      expect(result.message).to include("could not introspect")
    end
  end
end
