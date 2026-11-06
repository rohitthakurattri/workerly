module Payments
  # Every 5 minutes (config/schedule.yml): orders still unpaid and refunds still pending after a
  # couple of minutes are checked with the gateway, in case a webhook was lost.
  class SyncPendingJob < ApplicationJob
    queue_as :default

    WAIT = 2.minutes
    LOOKBACK = 1.day

    def perform(now: Time.current)
      Payment.where(method: "online", status: "created").where(created_at: (now - LOOKBACK)..(now - WAIT))
             .where.not(provider_order_id: nil).find_each { |p| each_safely(p) { Sync.call(p, now:) } }
      Refund.where(status: "pending").where(created_at: (now - LOOKBACK)..(now - WAIT))
            .where.not(provider_refund_id: nil).find_each { |r| each_safely(r) { Sync.refund(r, now:) } }
    end

    private

    # One bad order (or the gateway being down) must not stop the rest; the next run tries again.
    def each_safely(record)
      yield
    rescue Adapters::Payments::Error => e
      Rails.logger.warn("[Payments::SyncPending] #{record.class.name} #{record.id}: #{e.code} #{e.message}")
    end
  end
end
