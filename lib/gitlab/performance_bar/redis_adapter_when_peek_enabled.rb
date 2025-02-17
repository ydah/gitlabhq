# frozen_string_literal: true

# Adapted from https://github.com/peek/peek/blob/master/lib/peek/adapters/redis.rb
module Gitlab
  module PerformanceBar
    module RedisAdapterWhenPeekEnabled
      def save(request_id)
        return unless ::Gitlab::PerformanceBar.enabled_for_request?
        return if request_id.blank?

        super

        enqueue_stats_job(request_id)
      end

      # schedules a job which parses peek profile data and adds them
      # to a structured log
      # rubocop:disable Gitlab/ModuleWithInstanceVariables
      def enqueue_stats_job(request_id)
        return unless Feature.enabled?(:performance_bar_stats, type: :ops)

        @client.sadd?(GitlabPerformanceBarStatsWorker::STATS_KEY, request_id)

        # We skip transaction check as the transaction check fails the system spec for
        # spec/features/user_can_display_performance_bar_spec.rb.
        # See issue: https://gitlab.com/gitlab-org/gitlab/-/issues/441535
        uuid = Gitlab::ExclusiveLease.skipping_transaction_check do
          Gitlab::ExclusiveLease.new(
            GitlabPerformanceBarStatsWorker::LEASE_KEY,
            timeout: GitlabPerformanceBarStatsWorker::LEASE_TIMEOUT
          ).try_obtain
        end

        return unless uuid

        # stats key should be periodically processed and deleted by
        # GitlabPerformanceBarStatsWorker but if it doesn't happen for
        # some reason, we set expiration for the stats key to avoid
        # keeping millions of request ids which would be already expired
        # anyway
        # rubocop:disable Gitlab/ModuleWithInstanceVariables
        @client.expire(
          GitlabPerformanceBarStatsWorker::STATS_KEY,
          GitlabPerformanceBarStatsWorker::STATS_KEY_EXPIRE
        )

        GitlabPerformanceBarStatsWorker.perform_in(
          GitlabPerformanceBarStatsWorker::WORKER_DELAY,
          uuid
        )
      end
      # rubocop:enable Gitlab/ModuleWithInstanceVariables
    end
  end
end
