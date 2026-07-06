# frozen_string_literal: true

module Forseti
  module Audit
    module Sinks
      # Persists events to the forseti_audit_events table (Persist tier —
      # activated by the forseti:audit generator's migration).
      class ActiveRecord
        # @param event [Forseti::Audit::Event]
        # @return [void]
        def write(event)
          Forseti::AuditEvent.create!(**event.to_h)
        end

        # Fail-fast boot check (ADR 000, D2). A missing *table* is deliberately
        # not checked here — apps boot before migrating on deploy; the
        # audit.storage scanner check covers that.
        #
        # @raise [Forseti::Error] when Active Record isn't loaded
        def verify!
          return if defined?(::ActiveRecord)

          raise Error,
                "The :active_record audit sink requires Active Record, which is not loaded. " \
                "Use `config.audit.sinks = [:logger]`, or add Active Record and run " \
                "`bin/rails generate forseti:audit && bin/rails db:migrate`."
        end
      end
    end
  end
end
