# frozen_string_literal: true

class CreateForsetiConsentRecords < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :forseti_consent_records do |t|
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :purpose, null: false
      t.string :action, null: false
      t.string :policy_version
      t.json :metadata
      t.string :ip_address
      t.datetime :created_at, null: false
    end

    add_index :forseti_consent_records, %i[subject_type subject_id purpose]
    add_index :forseti_consent_records, :purpose
    add_index :forseti_consent_records, :created_at
  end
end
