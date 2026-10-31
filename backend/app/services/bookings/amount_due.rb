module Bookings
  # What the customer owes, computed only from revisions the customer approved (booking_approvals).
  # A revision the worker sent but the customer hasn't approved never counts, so no path can
  # charge more than was agreed. Stored on bookings.approved_total_minor after every change.
  #
  #   fixed:       approved initial quote + approved change orders
  #   inspection:  approved visit fee, or once the final price is approved:
  #                max(final, fee) when the fee is taken off the bill (default) or final + fee
  #                — plus approved change orders
  #   closed after inspection, or cancelled after the worker checked in: the visit fee only
  #   cancelled before check-in: nothing
  module AmountDue
    module_function

    def call(booking)
      revisions = BookingApproval.approved.where(booking_id: booking.id).includes(:quotation_revision).map(&:quotation_revision)
      sum = ->(stage) { revisions.select { |r| r.stage == stage }.sum(&:total_minor) }
      fee = sum.("inspection_fee")

      return booking.checked_in_at && booking.kind == "inspection" ? fee : 0 if booking.cancelled?
      return fee if booking.closed_after_inspection?

      base =
        if booking.kind == "fixed"
          sum.("initial")
        elsif revisions.any? { |r| r.stage == "final" }
          final = sum.("final")
          Workerly.config.inspection_fee_adjusted ? [ final, fee ].max : final + fee
        else
          fee
        end
      base + sum.("change_order")
    end
  end
end
