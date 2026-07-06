# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class AuditStorage < Check
        id          "audit.storage"
        severity    :high
        title       "Audit trail storage ready"
        description "With the :active_record sink configured, audit events need the " \
                    "forseti_audit_events table — a pending migration silently drops the trail " \
                    "(sink errors are reported, not raised, by default)."
        remediation "Run `bin/rails generate forseti:audit && bin/rails db:migrate`, or switch to " \
                    "`config.audit.sinks = [:logger]`."

        def applies?
          Forseti.config.audit.enabled? && Forseti.config.audit.sinks.include?(:active_record)
        end

        def not_applicable_reason
          "Audit module not enabled with the :active_record sink"
        end

        def call
          unless defined?(::ActiveRecord)
            return fail_with("The :active_record audit sink is configured but Active Record is not loaded")
          end

          if Forseti::AuditEvent.table_exists?
            pass("forseti_audit_events table present")
          else
            fail_with("forseti_audit_events table is missing — audit events cannot be persisted")
          end
        end
      end
    end
  end
end
