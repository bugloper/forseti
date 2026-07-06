# frozen_string_literal: true

module Forseti
  module Consent
    # Consent module configuration, available as +Forseti.config.consent+.
    class Config < Forseti::Config::Base
      setting :purposes,
              default: [],
              description: "Declared consent purposes (symbols). When non-empty, grant/withdraw " \
                           "raise on undeclared purposes — typo protection for legal evidence."
    end
  end
end
