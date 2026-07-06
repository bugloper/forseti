# frozen_string_literal: true

module Forseti
  module Scanner
    # Holds registered checks keyed by id (ADR 000, D7). Order is
    # deterministic: checks run and render sorted by id.
    class Registry
      # @param initial [Array<Class>] check classes to pre-register
      def initialize(initial = [])
        @checks = {}
        initial.each { |check| register(check) }
      end

      # @param check_class [Class] a {Forseti::Scanner::Check} subclass with an id
      # @return [Class] the registered class
      # @raise [Forseti::Error] for non-checks, missing ids, or duplicate ids
      def register(check_class)
        validate!(check_class)
        @checks[check_class.id] = check_class
      end

      # @param id [String]
      # @return [Class, nil] the removed check class
      def unregister(id)
        @checks.delete(id.to_s)
      end

      # @return [Array<Class>] all checks, sorted by id
      def checks
        @checks.values.sort_by(&:id)
      end

      # @param id [String]
      # @return [Class, nil]
      def [](id)
        @checks[id.to_s]
      end

      def include?(id)
        @checks.key?(id.to_s)
      end

      private

      def validate!(check_class)
        unless check_class.is_a?(Class) && check_class < Check
          raise Error, "#{check_class.inspect} is not a Forseti::Scanner::Check subclass"
        end
        raise Error, "Check #{check_class.name} declares no id" if check_class.id.nil?
        raise Error, "A check with id #{check_class.id.inspect} is already registered" if include?(check_class.id)
        raise Error, "Check #{check_class.id} declares no severity" if check_class.severity.nil?
      end
    end
  end
end
