# frozen_string_literal: true

require "rails/generators"
require "rails/generators/base"

module Forseti
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates the Forseti initializer at config/initializers/forseti.rb"

      def create_initializer
        copy_file "forseti.rb", "config/initializers/forseti.rb"
      end

      def show_next_steps
        say ""
        say "Forseti installed. Next steps:", :green
        say "  1. Run `bin/rails forseti:doctor` for your security posture report."
        say "  2. Review config/initializers/forseti.rb and opt into what you want."
      end
    end
  end
end
