# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class FilterParameters < Check
        # Probed behaviorally through ActiveSupport::ParameterFilter — we test
        # what the filter actually redacts, not what the config array looks
        # like (ADR 001 §7).
        PROBES = %w[password password_confirmation secret token api_key access_key ssn cvv].freeze
        FILTERED = "[FILTERED]"

        id          "privacy.filter_parameters"
        severity    :high
        title       "Sensitive parameter filtering"
        description "config.filter_parameters keeps credentials and PII out of logs and error reports."
        remediation "Restore config/initializers/filter_parameter_logging.rb with at least Rails' " \
                    "generated list: :passw, :email, :secret, :token, :_key, :crypt, :salt, " \
                    ":certificate, :otp, :ssn, :cvv, :cvc."

        def call
          filters = context.config.filter_parameters
          if filters.blank?
            return fail_with("config.filter_parameters is empty — passwords and tokens are logged in plaintext")
          end

          unfiltered = probe(filters)
          if unfiltered.empty?
            pass("Parameter filtering covers the common sensitive keys")
          else
            fail_with("Parameter filtering misses common sensitive keys",
                      details: unfiltered.map { |key| "`#{key}` is not filtered" })
          end
        end

        private

        def probe(filters)
          filter = ActiveSupport::ParameterFilter.new(filters)
          PROBES.reject { |key| filter.filter({ key => "probe" })[key] == FILTERED }
        end
      end
    end
  end
end
