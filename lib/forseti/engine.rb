# frozen_string_literal: true

module Forseti
  # Forseti's Rails engine.
  #
  # Deliberately inert (ADR 000, D2/D3): requiring the gem changes nothing
  # about application behavior. Persist-tier features (models, migrations,
  # routes) only activate through explicit generators, and enforcement only
  # through explicit configuration.
  class Engine < ::Rails::Engine
    isolate_namespace Forseti

    rake_tasks do
      load File.expand_path("tasks.rb", __dir__)
    end

    # Runs after the app's config/initializers/forseti.rb so the user's
    # Forseti.configure has been evaluated. Apps that never opt in get an
    # untouched middleware stack (ADR 000, D3).
    initializer "forseti.security.middleware", after: :load_config_initializers do |app|
      app.middleware.use Forseti::Security::Middleware if Forseti.config.security.active?
    end

    # Union semantics: the app's own filter entries are never removed. This
    # config is consumed after initialization (request env, AR
    # filter_attributes), so mutating it here is ordering-safe (ADR 003 §7).
    initializer "forseti.privacy.filter_parameters", after: :load_config_initializers do |app|
      if Forseti.config.privacy.filter_parameters_mode == :enforce
        app.config.filter_parameters |= Forseti::PII.filter_keys
      end
    end

    config.after_initialize do
      if Forseti.config.privacy.log_redaction_mode != :off && Rails.logger
        Forseti::Privacy::LogRedactor.install(Rails.logger)
      end

      # Fail fast on impossible Persist-tier configs (ADR 000, D2) — a
      # misconfigured audit trail or consent store should not boot quietly.
      Forseti::Audit.verify_sinks! if Forseti.config.audit.enabled?
      Forseti::Consent.verify! if Forseti.config.consent.enabled?
    end
  end
end
