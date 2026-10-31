module Shared
  # Daily: stored responses for Idempotency-Key replays are kept for 24 hours.
  class PurgeIdempotencyKeysJob < ApplicationJob
    queue_as :low

    def perform(now: Time.current)
      IdempotencyKey.where(created_at: ...(now - IdempotencyKey::RETENTION)).in_batches.delete_all
    end
  end
end
