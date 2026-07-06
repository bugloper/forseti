# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class HostAuthorization < Check
        id          "security.host_authorization"
        severity    :medium
        title       "Host header validation"
        description "With an empty config.hosts allowlist, Rails accepts any Host header, enabling " \
                    "host-header injection in generated URLs and password-reset links."
        remediation "Set `config.hosts = [\"example.com\", /.*\\.example\\.com/]` in " \
                    "config/environments/production.rb."
        production_only

        def call
          hosts = Array(context.config.hosts)

          if hosts.empty?
            fail_with("config.hosts is empty — every Host header is accepted")
          else
            pass("Host allowlist configured (#{hosts.size} #{hosts.size == 1 ? 'entry' : 'entries'})")
          end
        end
      end
    end
  end
end
