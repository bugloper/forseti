# frozen_string_literal: true

module Forseti
  # One consent state change — a grant or a withdrawal. Append-only, exactly
  # like the audit trail: once persisted, updates and destroys raise. The
  # history is the legal evidence; deliberately never prune it.
  class ConsentRecord < ::ActiveRecord::Base
    ACTIONS = %w[granted withdrawn].freeze

    belongs_to :subject, polymorphic: true

    validates :purpose, presence: true
    validates :action, presence: true, inclusion: { in: ACTIONS }

    def readonly?
      persisted?
    end
  end
end
