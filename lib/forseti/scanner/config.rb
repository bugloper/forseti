# frozen_string_literal: true

module Forseti
  module Scanner
    # Scanner configuration, available as +Forseti.config.scanner+.
    #
    # The scanner is Observe-tier: running a rake task is the opt-in, so there
    # is nothing to enable — these settings only tune behavior.
    class Config < Forseti::Config::Base
      setting :skip_checks,
              default: [],
              description: "Check ids to skip, e.g. [\"security.csp_nonce\"]."

      setting :fail_on,
              default: versioned("1.0" => :high),
              values: Severity::LEVELS + [:none],
              description: "forseti:doctor exits non-zero when a failed check is at least this severe. " \
                           ":none disables the exit code."
    end
  end
end
