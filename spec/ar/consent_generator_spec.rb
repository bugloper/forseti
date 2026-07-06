# frozen_string_literal: true

require "tmpdir"
require "generators/forseti/consent/consent_generator"

RSpec.describe Forseti::Generators::ConsentGenerator do
  it "creates a timestamped migration for the consent table" do
    Dir.mktmpdir do |dir|
      capture_stdout { described_class.start([], destination_root: dir) }

      migration = Dir[File.join(dir, "db/migrate/*_create_forseti_consent_records.rb")].sole
      content = File.read(migration)

      expect(content).to include("create_table :forseti_consent_records")
      expect(content).to include("t.string :purpose, null: false")
      expect(content).to match(/ActiveRecord::Migration\[\d+\.\d+\]/)
    end
  end
end
