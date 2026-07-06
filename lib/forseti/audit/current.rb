# frozen_string_literal: true

module Forseti
  module Audit
    # Per-request ambient audit context. Rails' executor resets it around
    # every request/job, so values can never leak across requests. Filled by
    # {Forseti::Audit::Controller} or manually (e.g. in jobs):
    #
    #   Forseti::Audit::Current.actor = batch_owner
    class Current < ActiveSupport::CurrentAttributes
      attribute :actor, :ip_address, :user_agent, :request_id
    end
  end
end
