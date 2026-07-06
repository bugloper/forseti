# frozen_string_literal: true

RSpec.describe "secure_headers gem integration (real gem, not stubs)" do
  let(:context) { fake_context }

  # Configuration.default is once-per-process: guarded by
  # `defined?(@default_config)` (so the ivar must be REMOVED, not nilled) and
  # by the NOOP entry it registers in @overrides.
  before do
    config_class = SecureHeaders::Configuration
    config_class.remove_instance_variable(:@default_config) if config_class.instance_variable_defined?(:@default_config)
    config_class.instance_variable_set(:@overrides, {})
  end

  def configure_secure_headers(&)
    SecureHeaders::Configuration.default(&)
  end

  describe "the security.csp check's introspection contract" do
    it "passes when the gem manages a real policy" do
      configure_secure_headers do |config|
        # CSP source keywords are literally quoted — the cop misfires here.
        config.csp = { default_src: %w['self'], script_src: %w['self'] } # rubocop:disable Lint/PercentStringArray
      end

      result = Forseti::Scanner::Checks::CSP.new(context).call

      expect(result).to be_passed
      expect(result.message).to include("secure_headers gem")
    end

    it "fails on the OPT_OUT dead-configuration footgun" do
      configure_secure_headers do |config|
        config.csp = { default_src: %w['self'] } # rubocop:disable Lint/PercentStringArray -- dead config, like the wild sighting
        config.csp = SecureHeaders::OPT_OUT
      end

      result = Forseti::Scanner::Checks::CSP.new(context).call

      expect(result).to be_failed
      expect(result.message).to include("OPT_OUT")
    end

    it "relies on the Configuration.dup API this gem version actually exposes" do
      configure_secure_headers { |config| config.csp = SecureHeaders::OPT_OUT }

      duped = SecureHeaders::Configuration.dup

      expect(duped).to respond_to(:csp)
      expect(duped.csp).to eq(SecureHeaders::OPT_OUT)
    end
  end

  describe "the security.default_headers check" do
    it "steps aside because headers are managed by the gem" do
      configure_secure_headers { |config| config.csp = SecureHeaders::OPT_OUT }
      config = fake_config
      config.action_dispatch.default_headers = {}

      result = Forseti::Scanner::Checks::DefaultHeaders.new(fake_context(config: config)).call

      expect(result).to be_skipped
      expect(result.skip_cause).to eq(:not_applicable)
      expect(result.message).to include("secure_headers gem")
    end
  end
end
