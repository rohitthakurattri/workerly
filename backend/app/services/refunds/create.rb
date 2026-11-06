module Refunds
  # Finance returns money from an online payment (all or part). The gateway is asked first; the
  # ledger is posted when the refund is processed (now, or on the refund.processed webhook).
  module Create
    module_function

    def call(payment:, amount_minor:, reason:, auth:, now: Time.current)
      reason = reason.to_s.strip
      raise ApplicationError.new(:reason_required) if reason.empty?

      refund = Booking.transaction do
        payment.booking.lock!
        payment.lock!
        raise ApplicationError.new(:not_refundable, status: :conflict, details: { status: payment.status, method: payment.method }) unless payment.online? && payment.settled?

        amount = amount_minor.to_i
        unless amount.positive? && amount <= payment.refundable_minor
          raise ApplicationError.new(:refund_too_large, details: { refundable: Shared::Money.to_h(payment.refundable_minor, payment.currency_code) })
        end

        r = payment.refunds.create!(amount_minor: amount, reason:, initiated_by: auth.user)
        ::Admin::Audit.record!(action: "payment.refunded", target: payment, reason:, changes: { amount_minor: amount }, auth:)
        r
      end

      result = Adapters::Payments.adapter.refund(provider_payment_id: payment.provider_payment_id, amount_minor: refund.amount_minor,
                                                 notes: { refund_id: refund.public_id })
      refund.update!(provider_refund_id: result[:id])
      result[:status] == "processed" ? Complete.call(refund:, now:) : refund
    rescue Adapters::Payments::Error => e
      refund&.update!(status: "failed")
      raise ApplicationError.new(:payment_gateway_error, status: :bad_gateway, details: { reason: e.code })
    end
  end
end
