# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"
require "rails/generators/active_record"

module Forseti
  module Generators
    class AuditGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates the migration for the forseti_audit_events table"

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        migration_template "create_forseti_audit_events.rb",
                           "db/migrate/create_forseti_audit_events.rb"
      end

      def show_next_steps
        say ""
        say "Audit storage generated. Next steps:", :green
        say "  1. Run `bin/rails db:migrate`."
        say "  2. Add `config.audit.enable!` to config/initializers/forseti.rb."
        say "  3. Record events with Forseti::Audit.record(:action, ...)."
      end

      private

      def migration_version
        "[#{::ActiveRecord::VERSION::STRING.to_f}]"
      end
    end
  end
end
