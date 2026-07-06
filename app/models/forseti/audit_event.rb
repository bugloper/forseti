# frozen_string_literal: true

module Forseti
  # One row per audit event — the durable trail behind the :active_record
  # sink. Append-only at the model layer: once persisted, updates and
  # destroys raise ActiveRecord::ReadOnlyRecord. (`delete_all` bypasses
  # Active Record entirely; deliberate pruning arrives with the Retention
  # module. For hard guarantees, revoke UPDATE/DELETE at the database.)
  class AuditEvent < ::ActiveRecord::Base
    belongs_to :actor, polymorphic: true, optional: true
    belongs_to :subject, polymorphic: true, optional: true

    validates :action, :occurred_at, presence: true

    def readonly?
      persisted?
    end
  end
end
