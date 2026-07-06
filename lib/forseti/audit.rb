# frozen_string_literal: true

module Forseti
  # The audit trail (ADR 004): a durable, append-only record of security- and
  # compliance-relevant events.
  #
  #   Forseti::Audit.record(:role_changed,
  #                         actor: admin, subject: user,
  #                         metadata: { from: "member", to: "admin" })
  #
  # Name events as past-tense verbs (:login_succeeded, :data_exported,
  # :record_erased) — the vocabulary is yours; Forseti stores and reports it.
  #
  # Events flow to configured sinks (ADR 000 D2/D6): :active_record persists
  # to forseti_audit_events, :logger emits single-line JSON, and any object
  # responding to #write(event) works (SIEM, Kafka, WORM stores). Every
  # dispatch also instruments "audit.forseti" for app subscribers.
  module Audit
    EVENT = "audit.forseti"

    # Distinguishes "actor not given — use ambient context" from an explicit
    # actor: nil (an actorless system event).
    UNSET = Object.new
    private_constant :UNSET

    class << self
      # Records one audit event. No-op unless the module is enabled (ADR 000,
      # D3). Explicit arguments beat the ambient {Forseti::Audit::Current}
      # context; metadata passes through the PII filter before storage.
      #
      # @param action [Symbol, String] past-tense event name
      # @param actor [Object, nil] who did it; defaults to Current.actor
      # @param subject [Object, nil] what it was done to
      # @param metadata [Hash] extra context; PII-filtered
      # @param request [ActionDispatch::Request, nil] source of ip/user_agent/request_id
      # @return [Forseti::Audit::Event, nil] nil when the module is disabled
      def record(action, actor: UNSET, subject: nil, metadata: {}, request: nil)
        config = Forseti.config.audit
        return unless config.enabled?

        event = build_event(action, actor, subject, metadata, request)
        ActiveSupport::Notifications.instrument(EVENT, event: event) do
          dispatch(event, config)
        end
        event
      end

      # Boot-time sink validation (fail fast, ADR 000 D2). Called by the
      # engine when the module is enabled.
      #
      # @return [void]
      # @raise [Forseti::Error] e.g. :active_record sink without Active Record
      def verify_sinks!
        resolved_sinks(Forseti.config.audit).each do |sink|
          sink.verify! if sink.respond_to?(:verify!)
        end
      end

      private

      def build_event(action, actor, subject, metadata, request)
        Event.new(
          action: action,
          actor: actor.equal?(UNSET) ? Current.actor : actor,
          subject: subject,
          metadata: filter_metadata(metadata),
          ip_address: request ? request.remote_ip : Current.ip_address,
          user_agent: request ? request.user_agent : Current.user_agent,
          request_id: request ? request.request_id : Current.request_id
        )
      end

      # Audit metadata must never become a PII dump: filter through the app's
      # filter_parameters plus the PII registry's keys (ADR 003).
      def filter_metadata(metadata)
        app_filters = Rails.application&.config&.filter_parameters || []
        ActiveSupport::ParameterFilter.new(app_filters | PII.filter_keys).filter(metadata)
      end

      def dispatch(event, config)
        resolved_sinks(config).each do |sink|
          sink.write(event)
        rescue StandardError => e
          raise if config.on_sink_error == :raise

          Rails.error.report(e, handled: true, context: { forseti: :audit_sink })
        end
      end

      def resolved_sinks(config)
        config.sinks.map { |entry| resolve_sink(entry) }
      end

      def resolve_sink(entry)
        case entry
        when :active_record then @active_record_sink ||= Sinks::ActiveRecord.new
        when :logger then @logger_sink ||= Sinks::Logger.new
        when Symbol
          raise ConfigurationError, "Unknown audit sink :#{entry}. Built-ins: :active_record, :logger"
        else
          unless entry.respond_to?(:write)
            raise ConfigurationError, "Audit sink #{entry.inspect} must respond to #write(event)"
          end

          entry
        end
      end
    end
  end
end
