# frozen_string_literal: true

module Forseti
  module PII
    # The built-in PII types (ADR 003 §7). Value detection is validator-backed
    # to kill false positives; key patterns match normalized names.
    #
    # Scanner probes stay compatible with Rails' generated filter list on
    # purpose — the coverage check shouldn't fail every default Rails app.
    # Stricter coverage (card_number, phone) arrives via enforcement
    # (privacy.filter_parameters!), not detection.
    module Builtins
      LUHN = lambda do |candidate|
        digits = candidate.gsub(/\D/, "")
        next false unless (13..19).cover?(digits.length)

        sum = digits.reverse.each_char.with_index.sum do |char, index|
          digit = char.to_i
          index.odd? ? (digit * 2).digits.sum : digit
        end
        (sum % 10).zero?
      end

      IBAN_MOD97 = lambda do |candidate|
        normalized = candidate.delete(" ").upcase
        next false unless normalized.match?(/\A[A-Z]{2}\d{2}[A-Z0-9]{11,30}\z/)

        rearranged = normalized[4..] + normalized[0, 4]
        numeric = rearranged.each_char.map { |c| c.match?(/[A-Z]/) ? (c.ord - 55).to_s : c }.join
        numeric.to_i % 97 == 1
      end

      IPV4_OCTETS = ->(candidate) { candidate.split(".").all? { |octet| octet.to_i <= 255 } }

      class << self
        def all # rubocop:disable Metrics/MethodLength
          [
            Type.new(key: :email, sensitivity: :high,
                     key_patterns: [/email/],
                     value_pattern: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/,
                     filter_keys: %i[email], probes: %w[email]),
            Type.new(key: :phone, sensitivity: :high,
                     key_patterns: [/phone|mobile/],
                     value_pattern: /\+\d[\d \-()]{5,17}\d/,
                     filter_keys: %i[phone mobile]),
            Type.new(key: :credit_card, sensitivity: :critical,
                     key_patterns: [/card number|credit card|\bpan\b|\bcvv\b|\bcvc\b/],
                     value_pattern: /\b\d(?:[ -]?\d){11,18}\b/, validator: LUHN,
                     filter_keys: %i[card_number pan cvv cvc], probes: %w[cvv]),
            Type.new(key: :ssn, sensitivity: :critical,
                     key_patterns: [/\bssn\b|social security/],
                     value_pattern: /\b\d{3}-\d{2}-\d{4}\b/,
                     filter_keys: %i[ssn], probes: %w[ssn]),
            Type.new(key: :iban, sensitivity: :critical,
                     key_patterns: [/\biban\b/],
                     value_pattern: /\b[A-Z]{2}\d{2} ?[A-Z0-9][A-Z0-9 ]{9,32}\b/, validator: IBAN_MOD97,
                     filter_keys: %i[iban]),
            Type.new(key: :ip_address, sensitivity: :medium,
                     key_patterns: [/\bip\b/],
                     value_pattern: /\b(?:\d{1,3}\.){3}\d{1,3}\b/, validator: IPV4_OCTETS),
            Type.new(key: :date_of_birth, sensitivity: :high,
                     key_patterns: [/date of birth|\bdob\b|birth ?date|birthday/],
                     filter_keys: %i[dob birth_date]),
            Type.new(key: :password, sensitivity: :critical,
                     key_patterns: [/passw/],
                     filter_keys: %i[passw], probes: %w[password password_confirmation]),
            Type.new(key: :api_credentials, sensitivity: :critical,
                     key_patterns: [/secret|token|api ?key|access ?key|private ?key|credential|\botp\b/],
                     filter_keys: %i[secret token _key crypt salt certificate otp],
                     probes: %w[secret token api_key access_key]),
            Type.new(key: :national_id, sensitivity: :critical,
                     key_patterns: [/passport|national id|tax id|aadhaar/],
                     filter_keys: %i[passport national_id tax_id])
          ]
        end
      end
    end
  end
end
