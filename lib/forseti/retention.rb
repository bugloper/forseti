# frozen_string_literal: true

module Forseti
  # Data retention execution (ADR 006): declared policies, previewed safely,
  # pruned deliberately, audited always.
  #
  #   config.retention.policy :stale_audit_events,
  #                           model: "Forseti::AuditEvent",
  #                           keep_for: 2.years, timestamp: :occurred_at, strategy: :delete
  #
  # `Forseti::Retention.preview` counts without deleting; `.run` prunes and
  # emits a :retention_pruned audit event per policy. Scheduling belongs to
  # the app (cron, solid_queue recurring, whenever) — the rake tasks are the
  # entry points.
  module Retention
    class << self
      # Dry run: eligible counts per policy, no deletion.
      #
      # @return [Array<Hash>] { policy:, eligible: } or { policy:, error: }
      def preview(now: Time.current)
        Forseti.config.retention.policies.map do |policy|
          { policy: policy.name, eligible: policy.eligible(now: now).count }
        rescue StandardError => e
          { policy: policy.name, error: "#{e.class}: #{e.message}" }
        end
      end

      # Prunes every policy. Failures are isolated per policy — one broken
      # policy can't block the others — and reported via Rails.error.
      #
      # @return [Array<Hash>] { policy:, deleted: } or { policy:, error: }
      def run(now: Time.current)
        Forseti.config.retention.policies.map { |policy| run_policy(policy, now: now) }
      end

      private

      def run_policy(policy, now:)
        deleted = policy.prune!(now: now)
        # Deletion is itself a compliance action — it leaves a trail.
        Audit.record(:retention_pruned, actor: :system,
                                        metadata: { policy: policy.name, deleted: deleted })
        { policy: policy.name, deleted: deleted }
      rescue StandardError => e
        Rails.error.report(e, handled: true, context: { forseti: :retention, policy: policy.name })
        { policy: policy.name, error: "#{e.class}: #{e.message}" }
      end
    end
  end
end
