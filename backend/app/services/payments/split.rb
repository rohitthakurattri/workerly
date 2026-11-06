module Payments
  # How a payment divides: Workerly's commission (percent of labour + fixed, from the booking's
  # snapshot of the commission rule), tax collected, and the worker's share. The customer pays
  # the full amount owed either way; commission only ever reduces the worker's share.
  module Split
    module_function

    Result = Data.define(:commission_minor, :tax_minor, :worker_share_minor)

    def call(booking, amount_minor)
      due = Bookings::AmountDue.breakdown(booking)
      bps, fixed = rule_for(booking)
      tax_total = due.tax_minor
      commission_total = [ ((due.labour_minor * bps) + 5_000) / 10_000 + fixed, due.total_minor - tax_total ].min
      commission_total = [ commission_total, 0 ].max

      # What earlier payments on this booking already took (normally there is only one payment).
      prior = booking.payments.settled.where.not(commission_minor: nil)
      commission = [ commission_total - prior.sum(:commission_minor), 0 ].max
      tax = [ tax_total - prior.sum(:tax_minor), 0 ].max
      commission, tax = scale(commission, tax, amount_minor)
      Result.new(commission_minor: commission, tax_minor: tax, worker_share_minor: amount_minor - commission - tax)
    end

    # Commission snapshot taken at booking (Quotations::Accept); older bookings use today's rule.
    def rule_for(booking)
      return [ booking.commission_bps, booking.commission_fixed_minor.to_i ] if booking.commission_bps

      rule = CommissionRule.for(city: booking.service_request.city, category: booking.service_request.service_category)
      [ rule&.percent_bps || 0, rule&.fixed_minor || 0 ]
    end

    # Never take more than the payment itself.
    def scale(commission, tax, amount)
      return [ commission, tax ] if commission + tax <= amount

      tax = [ tax, amount ].min
      [ [ commission, amount - tax ].min, tax ]
    end
  end
end
