# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"
require "rails/generators/active_record"

module Forseti
  module Generators
    class ConsentGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates the migration for the forseti_consent_records table"

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        migration_template "create_forseti_consent_records.rb",
                           "db/migrate/create_forseti_consent_records.rb"
      end

      def show_next_steps
        say ""
        say "Consent storage generated. Next steps:", :green
        say "  1. Run `bin/rails db:migrate`."
        say "  2. Add `config.consent.enable!` (and optionally declared purposes) to the initializer."
        say "  3. Record consent with Forseti::Consent.grant(user, :purpose, policy_version: ...)."
      end

      private

      def migration_version
        "[#{::ActiveRecord::VERSION::STRING.to_f}]"
      end
    end
  end
end
