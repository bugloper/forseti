# frozen_string_literal: true

module Forseti
  module Audit
    # Opt-in controller concern (ADR 000, D3 — nothing auto-injects) that
    # fills {Forseti::Audit::Current} once per request, so call sites shrink
    # to Forseti::Audit.record(:action, subject: record).
    #
    #   class ApplicationController < ActionController::Base
    #     include Forseti::Audit::Controller
    #   end
    module Controller
      extend ActiveSupport::Concern

      included do
        before_action :set_forseti_audit_context
      end

      private

      def set_forseti_audit_context
        Current.ip_address = request.remote_ip
        Current.user_agent = request.user_agent
        Current.request_id = request.request_id
        Current.actor = forseti_audit_actor
      end

      def forseti_audit_actor
        actor_method = Forseti.config.audit.actor_method
        send(actor_method) if actor_method && respond_to?(actor_method, true)
      end
    end
  end
end
