# frozen_string_literal: true

# The Persist-tier harness (ADR 004 §7): boots the AR-less dummy app via
# spec_helper, then loads Active Record *standalone* — no railtie — proving
# the engine model and AR sink don't depend on the framework wiring.
require "spec_helper"
require "active_record"

# activerecord pulls its matching activesupport/railties via the Gemfile, so
# versions always line up with the appraisal.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
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

  create_table :users do |t|
    t.string :name
    t.datetime :deactivated_at
    t.datetime :created_at
  end
end

class User < ActiveRecord::Base; end
