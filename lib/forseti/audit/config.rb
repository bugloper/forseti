# frozen_string_literal: true

module Forseti
  module Audit
    # Audit module configuration, available as +Forseti.config.audit+.
    class Config < Forseti::Config::Base
      setting :sinks,
              default: versioned("1.0" => [:active_record]),
              description: "Where events go: :active_record, :logger, or any object responding to " \
                           "#write(event). All sinks receive every event."

      setting :actor_method,
              default: :current_user,
              description: "Controller method the Forseti::Audit::Controller concern calls to fill " \
                           "Current.actor."

      setting :on_sink_error,
              default: versioned("1.0" => :report),
              values: %i[report raise],
              description: ":report sends sink failures to Rails.error and keeps the request alive; " \
                           ":raise fails closed for strict compliance postures."
    end
  end
end
