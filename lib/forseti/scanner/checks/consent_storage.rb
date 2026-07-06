# frozen_string_literal: true

module Forseti
  module Scanner
    module Checks
      class ConsentStorage < Check
        id          "consent.storage"
        severity    :high
        title       "Consent record storage ready"
        description "With the consent module enabled, grants and withdrawals need the " \
                    "forseti_consent_records table — without it every consent call raises."
        remediation "Run `bin/rails generate forseti:consent && bin/rails db:migrate`."

        def applies?
          Forseti.config.consent.enabled?
        end

        def not_applicable_reason
          "Consent module not enabled"
        end

        def call
          unless defined?(::ActiveRecord)
            return fail_with("The consent module is enabled but Active Record is not loaded")
          end

          if Forseti::ConsentRecord.table_exists?
            pass("forseti_consent_records table present")
          else
            fail_with("forseti_consent_records table is missing — consent calls will raise")
          end
        end
      end
    end
  end
end
