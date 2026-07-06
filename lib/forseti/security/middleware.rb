# frozen_string_literal: true

module Forseti
  module Security
    # Response middleware that fills missing security headers (ADR 002).
    #
    # Contract: fill, never override or remove. A header already present —
    # from Rails defaults, a controller, or another middleware — always wins.
    # The baseline CSP only applies to HTML responses carrying no CSP header.
    class Middleware
      CONTENT_TYPE = "Content-Type"
      CSP = "Content-Security-Policy"
      CSP_REPORT_ONLY = "Content-Security-Policy-Report-Only"

      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)
        config = Forseti.config.security

        fill_static_headers(headers, config) if config.headers_mode == :enforce
        fill_csp(headers, config) unless config.csp_mode == :off

        [status, headers, body]
      end

      private

      def fill_static_headers(headers, config)
        fill(headers, "X-Content-Type-Options", "nosniff")
        fill(headers, "X-Frame-Options", config.frame_options)
        fill(headers, "Referrer-Policy", config.referrer_policy)
        fill(headers, "X-Permitted-Cross-Domain-Policies", "none")
      end

      def fill_csp(headers, config)
        return unless html?(headers)
        return if header?(headers, CSP) || header?(headers, CSP_REPORT_ONLY)

        name = config.csp_mode == :enforce ? CSP : CSP_REPORT_ONLY
        policy = config.csp_policy
        policy = "#{policy}; report-uri #{config.csp_report_uri}" if config.csp_report_uri
        write(headers, name, policy)
      end

      def fill(headers, name, value)
        write(headers, name, value) unless value.nil? || header?(headers, name)
      end

      def header?(headers, name)
        headers.each_key.any? { |key| key.casecmp?(name) }
      end

      def write(headers, name, value)
        headers[rack3? ? name.downcase : name] = value
      end

      def html?(headers)
        content_type = headers.find { |key, _value| key.casecmp?(CONTENT_TYPE) }&.last
        content_type.to_s.include?("text/html")
      end

      def rack3?
        ::Rack.release >= "3"
      end
    end
  end
end
