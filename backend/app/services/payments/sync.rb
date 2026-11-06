module Payments
  # Asks the gateway directly (authenticated with our secret) what happened to an order, instead
  # of waiting for its webhook. Same effect as the webhook and just as safe to repeat: Capture is
  # idempotent and keyed. Used right after checkout (so test mode works on localhost, where no
  # webhook can arrive) and by SyncPendingJob for webhooks that never came.
  module Sync
    module_function

    # Customers can retry a failed attempt inside the same checkout, so an order only counts as
    # failed once nobody could still be paying it.
    FAIL_AFTER = 30.minutes

    def call(payment, now: Time.current, adapter: Adapters::Payments.adapter)
      return payment unless payment.online? && payment.created? && payment.provider_order_id.present?

      attempts = adapter.order_payments(payment.provider_order_id)
      if (captured = attempts.find { |a| a[:status].to_s == "captured" })
        return Capture.call(payment:, provider_payment_id: captured[:id], amount_minor: captured[:amount],
                            currency: captured[:currency], now:)
      end
      if attempts.any? && attempts.all? { |a| a[:status].to_s == "failed" } && payment.created_at < now - FAIL_AFTER
        payment.with_lock do
          payment.update!(status: "failed", failed_at: now, failure_reason: attempts.last[:error_description].to_s.first(255)) if payment.created?
        end
      end
      payment
    end

    # A refund the webhook never confirmed.
    def refund(refund, now: Time.current, adapter: Adapters::Payments.adapter)
      return refund unless refund.status == "pending" && refund.provider_refund_id.present?

      case adapter.fetch_refund(refund.provider_refund_id)[:status].to_s
      when "processed" then Refunds::Complete.call(refund:, now:)
      when "failed" then refund.with_lock { refund.update!(status: "failed") if refund.status == "pending" }
      end
      refund
    end
  end
end
