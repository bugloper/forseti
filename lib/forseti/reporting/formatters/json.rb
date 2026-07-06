# frozen_string_literal: true

require "json"

module Forseti
  module Reporting
    module Formatters
      # Machine-readable output for forseti:report. The shape is
      # {Forseti::Reporting::Report#to_h}, versioned via schema_version.
      class JSON
        # @param report [Forseti::Reporting::Report]
        def initialize(report)
          @report = report
        end

        # @return [String] pretty-printed JSON
        def render
          ::JSON.pretty_generate(@report.to_h)
        end
      end
    end
  end
end
