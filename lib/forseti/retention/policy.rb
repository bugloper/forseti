# frozen_string_literal: true

module Forseti
  module Retention
    # One retention rule: which records, how long they live, and how they go.
    #
    # Strategies: :destroy (default) runs callbacks and dependent associations
    # — right for user-ish data; :delete issues delete_all — required for the
    # readonly audit model and right for high-volume rows with no dependents.
    class Policy
      STRATEGIES = %i[destroy delete].freeze

      attr_reader :name, :model_name, :keep_for, :timestamp, :strategy, :scope

      def initialize(name:, model:, keep_for:, timestamp: :created_at, strategy: :destroy, scope: nil)
        validate!(name, strategy, keep_for)

        @name = name.to_sym
        @model_name = model.to_s
        @keep_for = keep_for
        @timestamp = timestamp.to_sym
        @strategy = strategy
        @scope = scope
        freeze
      end

      # @return [Class] the model, resolved lazily so config can load before AR
      def model
        model_name.constantize
      end

      # Records older than the horizon, with the policy's scope applied.
      #
      # @return [ActiveRecord::Relation]
      def eligible(now: Time.current)
        relation = model.where(model.arel_table[timestamp].lt(now - keep_for))
        scope ? scope.call(relation) : relation
      end

      # @return [Integer] number of records removed
      def prune!(now: Time.current)
        relation = eligible(now: now)
        return relation.delete_all if strategy == :delete

        count = 0
        relation.find_each do |record|
          record.destroy!
          count += 1
        end
        count
      end

      private

      def validate!(name, strategy, keep_for)
        unless STRATEGIES.include?(strategy)
          raise ConfigurationError,
                "Retention policy #{name.inspect}: unknown strategy #{strategy.inspect}. " \
                "Strategies: #{STRATEGIES.join(', ')}"
        end
        return if keep_for.respond_to?(:ago)

        raise ConfigurationError,
              "Retention policy #{name.inspect}: keep_for must be a duration (e.g. 2.years)"
      end
    end
  end
end
