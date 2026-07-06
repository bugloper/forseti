# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class LoadDefaults < Check
        MINIMUM = 7.0

        id          "security.load_defaults"
        severity    :medium
        title       "Modern framework defaults"
        description "config.load_defaults pins which generation of Rails security defaults the app runs with."
        remediation "Set `config.load_defaults 7.1` (or newer) in config/application.rb and work through " \
                    "the new_framework_defaults initializer."

        def call
          version = context.config.loaded_config_version

          if version.nil?
            fail_with("config.load_defaults is never called — the app runs with pre-5.0 era defaults")
          elsif version.to_f < MINIMUM
            fail_with("config.load_defaults is pinned to #{version}, predating the #{MINIMUM} security defaults")
          else
            pass("Framework defaults pinned to #{version}")
          end
        end
      end
    end
  end
end
