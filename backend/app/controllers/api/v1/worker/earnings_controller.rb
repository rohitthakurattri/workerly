module Api
  module V1
    module Worker
      class EarningsController < BaseController
        # GET /api/v1/worker/earnings — balance (held for you, commission you owe on cash jobs),
        # each paid job with Workerly's commission, and payouts.
        def index
          authorize [ :worker, Booking ], :index?
          balance = Payouts::Balance.call(current_profile)
          payments = Payment.settled.joins(:booking).where(bookings: { worker_profile_id: current_profile.id })
                            .includes(booking: { service_request: :service_category }).order(captured_at: :desc).limit(50)
          money = ->(m) { Shared::Money.to_h(m.to_i, balance.currency) }
          render_data({
            balance: { held: money.(balance.payable_minor), owed: money.(balance.owed_minor), net: money.(balance.net_minor) },
            jobs: payments.map do |p|
              { booking_id: p.booking.public_id, category: p.booking.service_request.service_category.name, method: p.method,
                amount: money.(p.amount_minor), commission: money.(p.commission_minor), tax: money.(p.tax_minor),
                earnings: money.(p.worker_share_minor), refunded: money.(p.refunded_minor), paid_at: p.captured_at.iso8601 }
            end,
            payouts: current_profile.payouts.order(paid_at: :desc).limit(50).map do |po|
              { id: po.public_id, amount: money.(po.amount_minor), reference: po.provider_ref, paid_at: po.paid_at.iso8601 }
            end
          })
        end
      end
    end
  end
end
