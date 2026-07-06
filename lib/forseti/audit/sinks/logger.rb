# frozen_string_literal: true

require "json"

module Forseti
  module Audit
    module Sinks
      # Emits events as single-line JSON through the Rails logger. Works with
      # zero database — the audit option for AR-less apps, and a cheap way to
      # ship events to log-based pipelines.
      class Logger
        # @param logger [::Logger, nil] defaults to Rails.logger at write time
        def initialize(logger = nil)
          @logger             = logger
        end

        # @param event [Forseti::Audit::Event]
        # @return [void]
        def write(event)
          (@logger || Rails.logger).info(
            ::JSON.generate(forseti_audit: event.to_h)
          )
        end
      end
    end
  end
end
