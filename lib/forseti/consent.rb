# frozen_string_literal: true

module Forseti
  # Provable, purpose-specific, versioned, withdrawable consent (ADR 006).
  #
  #   Forseti::Consent.grant(user, :marketing_emails, policy_version: "2026-03")
  #   Forseti::Consent.granted?(user, :marketing_emails)                            # => true
  #   Forseti::Consent.granted?(user, :marketing_emails, policy_version: "2026-04") # => false
  #   Forseti::Consent.withdraw(user, :marketing_emails)
  #
  # Records are append-only — every grant and withdrawal is a new row, and the
  # current state is the newest record per subject and purpose. That history
  # IS the legal evidence; never point a retention policy at it.
  #
  # Unlike Audit.record, these calls work whether or not the module is
  # enabled: silently dropping a consent grant would destroy evidence.
  # `enable!` gates boot-time storage verification and compliance signaling.
  module Consent
    class << self
      # Records a grant. Also emits a :consent_granted audit event.
      #
      # @param subject [Object] usually a user record
      # @param purpose [Symbol, String] e.g. :marketing_emails
      # @param policy_version [String, nil] version of the policy text consented to
      # @param metadata [Hash] extra context (source, locale, ...)
      # @return [Forseti::ConsentRecord]
      def grant(subject, purpose, policy_version: nil, metadata: {})
        record!(subject, purpose, "granted", policy_version: policy_version, metadata: metadata)
      end

      # Records a withdrawal. Also emits a :consent_withdrawn audit event.
      #
      # @return [Forseti::ConsentRecord]
      def withdraw(subject, purpose, metadata: {})
        record!(subject, purpose, "withdrawn", metadata: metadata)
      end

      # Whether the subject's newest record for the purpose is a grant. With
      # +policy_version:+, the grant must also match that version — a false
      # here is the re-consent trigger after policy text changes.
      def granted?(subject, purpose, policy_version: nil)
        latest = latest_record(subject, purpose)
        return false unless latest&.action == "granted"

        policy_version.nil? || latest.policy_version == policy_version
      end

      # The full evidence trail, newest first.
      #
      # @param purpose [Symbol, String, nil] all purposes when nil
      # @return [ActiveRecord::Relation]
      def history(subject, purpose = nil)
        ensure_available!
        records = ConsentRecord.where(subject: subject).order(created_at: :desc, id: :desc)
        purpose ? records.where(purpose: purpose.to_s) : records
      end

      # Persist-tier fail-fast (ADR 000, D2), called at boot when enabled.
      #
      # @raise [Forseti::Error] when Active Record isn't loaded
      def verify!
        return if defined?(::ActiveRecord)

        raise Error,
              "Forseti::Consent requires Active Record, which is not loaded. " \
              "Add Active Record and run `bin/rails generate forseti:consent && bin/rails db:migrate`."
      end

      private

      def record!(subject, purpose, action, policy_version: nil, metadata: {})
        ensure_available!
        validate_purpose!(purpose)

        record = ConsentRecord.create!(
          subject: subject,
          purpose: purpose.to_s,
          action: action,
          policy_version: policy_version,
          metadata: metadata,
          ip_address: Audit::Current.ip_address
        )
        Audit.record(:"consent_#{action}", subject: subject,
                                           metadata: { purpose: purpose.to_s,
                                                       policy_version: policy_version }.compact)
        record
      end

      def latest_record(subject, purpose)
        ensure_available!
        ConsentRecord.where(subject: subject, purpose: purpose.to_s)
                     .order(created_at: :desc, id: :desc).first
      end

      def validate_purpose!(purpose)
        declared = Forseti.config.consent.purposes
        return if declared.empty? || declared.include?(purpose.to_sym)

        raise ConfigurationError,
              "Unknown consent purpose #{purpose.inspect}. Declared purposes: " \
              "#{declared.join(', ')} (config.consent.purposes)"
      end

      def ensure_available!
        verify!
      end
    end
  end
end
