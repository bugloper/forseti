# frozen_string_literal: true

module ScannerHelpers
  # A fully hardened fake app configuration; individual examples break one
  # aspect at a time. Mirrors the config surface the built-in checks inspect.
  def fake_config
    config = ActiveSupport::OrderedOptions.new
    config.loaded_config_version = 8.0
    config.force_ssl = true
    config.ssl_options = {}
    config.hosts = ["example.com"]
    config.session_options = {}
    config.log_level = :info
    config.content_security_policy = nil
    config.content_security_policy_report_only = false
    config.content_security_policy_nonce_generator = nil
    config.filter_parameters = %i[passw email secret token _key crypt salt certificate otp ssn cvv cvc]
    config.action_controller = ActiveSupport::OrderedOptions.new
    config.action_controller.default_protect_from_forgery = true
    config.action_controller.forgery_protection_origin_check = true
    config.action_controller.raise_on_open_redirects = true
    config.action_dispatch = ActiveSupport::OrderedOptions.new
    config.action_dispatch.cookies_same_site_protection = :lax
    config.action_dispatch.default_headers = {
      "X-Frame-Options" => "SAMEORIGIN",
      "X-Content-Type-Options" => "nosniff",
      "Referrer-Policy" => "strict-origin-when-cross-origin"
    }
    config
  end

  FakeApp = Struct.new(:config, :root)

  def fake_context(env: "production", config: fake_config, root: Pathname.new("/nonexistent"))
    Forseti::Scanner::Context.new(app: FakeApp.new(config, root), env: env)
  end

  # A minimal valid check class for registry/runner/score specs.
  def build_check(check_id:, severity: :medium, production_only: false, applies: true, &body)
    Class.new(Forseti::Scanner::Check) do
      id check_id
      severity severity
      title "Test check #{check_id}"
      remediation "Fix it."
      self.production_only(true) if production_only

      define_method(:applies?) { applies }
      define_method(:call, &body) if body
    end
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end

RSpec.configure do |config|
  config.include ScannerHelpers
  config.after { Forseti::Scanner.reset_registry! }
end
