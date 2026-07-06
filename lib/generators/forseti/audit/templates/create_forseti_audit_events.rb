# frozen_string_literal: true

class CreateForsetiAuditEvents < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :forseti_audit_events do |t|
      t.string :action, null: false
      t.string :actor_type
      t.bigint :actor_id
      t.string :subject_type
      t.bigint :subject_id
      t.json :metadata
      t.string :ip_address
      t.string :user_agent
      t.string :request_id
      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false
    end

    add_index :forseti_audit_events, :action
    add_index :forseti_audit_events, %i[actor_type actor_id]
    add_index :forseti_audit_events, %i[subject_type subject_id]
    add_index :forseti_audit_events, :occurred_at
    add_index :forseti_audit_events, :request_id
  end
end
