# frozen_string_literal: true

module Forseti
  module Audit
    # An immutable audit event. {#to_h} is the sink contract — every sink
    # receives exactly these keys.
    class Event
      attr_reader :action, :actor_type, :actor_id, :subject_type, :subject_id,
                  :metadata, :ip_address, :user_agent, :request_id, :occurred_at

      def initialize(action:, actor: nil, subject: nil, metadata: {}, ip_address: nil,
                     user_agent: nil, request_id: nil, occurred_at: Time.current)
        @action = action.to_s
        @actor_type, @actor_id = polymorphic_reference(actor)
        @subject_type, @subject_id = polymorphic_reference(subject)
        @metadata = metadata
        @ip_address = ip_address
        @user_agent = user_agent
        @request_id = request_id
        @occurred_at = occurred_at
        freeze
      end

      # @return [Hash]
      def to_h
        {
          action: action,
          actor_type: actor_type, actor_id: actor_id,
          subject_type: subject_type, subject_id: subject_id,
          metadata: metadata,
          ip_address: ip_address, user_agent: user_agent, request_id: request_id,
          occurred_at: occurred_at
        }
      end

      private

      # Records (anything with #id) become ["User", 42]; symbols/strings
      # become a bare type ("system"); nil stays nil.
      def polymorphic_reference(object)
        case object
        when nil then [nil, nil]
        when Symbol, String then [object.to_s, nil]
        else
          [object.class.name, object.respond_to?(:id) ? object.id : nil]
        end
      end
    end
  end
end
