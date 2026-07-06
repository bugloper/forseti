# frozen_string_literal: true

require "tmpdir"

RSpec.describe "Built-in checks" do
  let(:config) { fake_config }
  let(:context) { fake_context(config: config) }

  def run_check(check_class, ctx = context)
    check_class.new(ctx).call
  end

  describe Forseti::Scanner::Checks::LoadDefaults do
    it "passes on modern pins" do
      expect(run_check(described_class)).to be_passed
    end

    it "fails when load_defaults is never called" do
      config.loaded_config_version = nil
      expect(run_check(described_class)).to be_failed
    end

    it "fails on pins older than 7.0" do
      config.loaded_config_version = 6.1
      result = run_check(described_class)

      expect(result).to be_failed
      expect(result.message).to include("6.1")
    end
  end

  describe Forseti::Scanner::Checks::ForceSsl do
    it "passes when enabled" do
      expect(run_check(described_class)).to be_passed
    end

    it "fails when disabled" do
      config.force_ssl = false
      expect(run_check(described_class)).to be_failed
    end
  end

  describe Forseti::Scanner::Checks::HSTS do
    it "does not apply without force_ssl" do
      config.force_ssl = false
      expect(described_class.new(context).applies?).to be(false)
    end

    it "passes with default ssl_options" do
      expect(run_check(described_class)).to be_passed
    end

    it "fails when hsts is explicitly disabled" do
      config.ssl_options = { hsts: false }
      expect(run_check(described_class)).to be_failed
    end

    it "fails on sub-year expiry" do
      config.ssl_options = { hsts: { expires_in: 3600 } }
      expect(run_check(described_class)).to be_failed
    end

    it "passes on long expiry" do
      config.ssl_options = { hsts: { expires_in: 63_072_000 } }
      expect(run_check(described_class)).to be_passed
    end
  end

  describe Forseti::Scanner::Checks::HostAuthorization do
    it "passes with an allowlist" do
      expect(run_check(described_class)).to be_passed
    end

    it "fails with an empty allowlist" do
      config.hosts = []
      expect(run_check(described_class)).to be_failed
    end
  end

  describe Forseti::Scanner::Checks::Cookies do
    it "passes when hardened" do
      expect(run_check(described_class)).to be_passed
    end

    it "fails without same-site protection" do
      config.action_dispatch.cookies_same_site_protection = nil
      result = run_check(described_class)

      expect(result).to be_failed
      expect(result.details.join).to include("same_site")
    end

    it "fails when the session cookie disables httponly" do
      config.session_options = { httponly: false }
      expect(run_check(described_class)).to be_failed
    end

    it "fails in production without a secure cookie path" do
      config.force_ssl = false
      expect(run_check(described_class)).to be_failed
    end

    it "does not require the secure flag outside production" do
      config.force_ssl = false
      result = run_check(described_class, fake_context(env: "development", config: config))

      expect(result).to be_passed
    end
  end

  describe Forseti::Scanner::Checks::CSP do
    it "fails without a policy" do
      expect(run_check(described_class)).to be_failed
    end

    it "passes with an enforcing policy" do
      config.content_security_policy = Object.new
      expect(run_check(described_class)).to be_passed
    end

    it "passes report-only policies with a caveat" do
      config.content_security_policy = Object.new
      config.content_security_policy_report_only = true
      result = run_check(described_class)

      expect(result).to be_passed
      expect(result.details.join).to include("report-only")
    end
  end

  describe Forseti::Scanner::Checks::CSPNonce do
    it "does not apply without a CSP" do
      expect(described_class.new(context).applies?).to be(false)
    end

    it "fails without a nonce generator" do
      config.content_security_policy = Object.new
      expect(run_check(described_class)).to be_failed
    end

    it "passes with one" do
      config.content_security_policy = Object.new
      config.content_security_policy_nonce_generator = ->(request) { request.object_id.to_s }
      expect(run_check(described_class)).to be_passed
    end
  end

  describe Forseti::Scanner::Checks::DefaultHeaders do
    it "passes with the Rails defaults" do
      expect(run_check(described_class)).to be_passed
    end

    it "fails when headers are stripped" do
      config.action_dispatch.default_headers = {}
      result = run_check(described_class)

      expect(result).to be_failed
      expect(result.details.size).to eq(3)
    end

    it "accepts a missing X-Frame-Options when the CSP sets frame-ancestors" do
      config.action_dispatch.default_headers = {
        "X-Content-Type-Options" => "nosniff", "Referrer-Policy" => "strict-origin-when-cross-origin"
      }
      config.content_security_policy = Struct.new(:directives).new({ "frame-ancestors" => ["'self'"] })

      expect(run_check(described_class)).to be_passed
    end
  end

  describe Forseti::Scanner::Checks::Csrf do
    it "passes when protected" do
      expect(run_check(described_class)).to be_passed
    end

    it "fails when explicitly disabled" do
      config.action_controller.default_protect_from_forgery = false
      expect(run_check(described_class)).to be_failed
    end

    it "fails when unset" do
      config.action_controller.default_protect_from_forgery = nil
      expect(run_check(described_class)).to be_failed
    end

    it "fails when origin checking is disabled" do
      config.action_controller.forgery_protection_origin_check = false
      expect(run_check(described_class)).to be_failed
    end
  end

  describe Forseti::Scanner::Checks::OpenRedirects do
    it "passes when raising on open redirects (legacy setting)" do
      expect(run_check(described_class)).to be_passed
    end

    it "fails when the legacy setting is off" do
      config.action_controller.raise_on_open_redirects = false
      expect(run_check(described_class)).to be_failed
    end

    it "passes when Rails 8.1's action_on_open_redirect raises" do
      config.action_controller.action_on_open_redirect = :raise
      expect(run_check(described_class)).to be_passed
    end

    it "fails when Rails 8.1's action_on_open_redirect only logs" do
      config.action_controller.action_on_open_redirect = :log
      result = run_check(described_class)

      expect(result).to be_failed
      expect(result.message).to include(":log")
    end
  end

  describe Forseti::Scanner::Checks::MasterKey do
    def in_fake_app(gitignore: nil, master_key: true)
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        FileUtils.mkdir_p(root.join("config"))
        FileUtils.mkdir_p(root.join(".git"))
        root.join("config/master.key").write("0" * 32) if master_key
        root.join(".gitignore").write(gitignore) if gitignore
        yield fake_context(config: config, root: root)
      end
    end

    it "does not apply without a master key" do
      in_fake_app(master_key: false) do |ctx|
        expect(described_class.new(ctx).applies?).to be(false)
      end
    end

    it "passes when gitignored by path" do
      in_fake_app(gitignore: "/config/master.key\n") do |ctx|
        expect(run_check(described_class, ctx)).to be_passed
      end
    end

    it "passes when gitignored by glob" do
      in_fake_app(gitignore: "*.key\n") do |ctx|
        expect(run_check(described_class, ctx)).to be_passed
      end
    end

    it "fails without a matching pattern" do
      in_fake_app(gitignore: "log/\n# config/master.key\n") do |ctx|
        expect(run_check(described_class, ctx)).to be_failed
      end
    end

    it "fails without a .gitignore at all" do
      in_fake_app do |ctx|
        expect(run_check(described_class, ctx)).to be_failed
      end
    end
  end

  describe Forseti::Scanner::Checks::FilterParameters do
    it "passes with the Rails generated list" do
      expect(run_check(described_class)).to be_passed
    end

    it "fails when empty" do
      config.filter_parameters = []
      expect(run_check(described_class)).to be_failed
    end

    it "fails listing unfiltered probe keys" do
      config.filter_parameters = [:passw]
      result = run_check(described_class)

      expect(result).to be_failed
      expect(result.details.join).to include("ssn")
    end
  end

  describe Forseti::Scanner::Checks::LogLevel do
    it "passes at :info" do
      expect(run_check(described_class)).to be_passed
    end

    it "fails at :debug" do
      config.log_level = :debug
      expect(run_check(described_class)).to be_failed
    end
  end
end
