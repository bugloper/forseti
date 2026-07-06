# frozen_string_literal: true

module Forseti
  module Scanner
    # Everything a check may inspect, wrapped so checks never reach for
    # globals — which is also what makes them unit-testable against
    # hand-built configuration.
    class Context
      # @param app [#config, #root] defaults to the booted Rails application
      # @param env [String, ActiveSupport::EnvironmentInquirer]
      def initialize(app: Rails.application, env: Rails.env)
        @app = app
        @env = env.to_s
      end

      # @return [String]
      attr_reader :env

      # @return [Object] the application's configuration
      delegate :config, to: :@app

      # @return [Pathname] the application root
      delegate :root, to: :@app

      # Whether this environment should be held to production posture.
      # Staging environments deploy production-like and are checked as such.
      def production_like?
        %w[production staging].include?(env)
      end

      # @return [String] the application's class name, for report headers
      def app_name
        @app.class.name.to_s.split("::").first || "Application"
      end
    end
  end
end
