# frozen_string_literal: true

require "tmpdir"
require "generators/forseti/audit/audit_generator"

RSpec.describe Forseti::Generators::AuditGenerator do
  it "creates a timestamped migration for the audit table" do
    Dir.mktmpdir do |dir|
      capture_stdout { described_class.start([], destination_root: dir) }

      migration = Dir[File.join(dir, "db/migrate/*_create_forseti_audit_events.rb")].sole
      content = File.read(migration)

      expect(File.basename(migration)).to match(/\A\d{14}_create_forseti_audit_events\.rb\z/)
      expect(content).to include("create_table :forseti_audit_events")
      expect(content).to match(/ActiveRecord::Migration\[\d+\.\d+\]/)
      expect(content).to include("t.datetime :occurred_at, null: false")
    end
  end
end
