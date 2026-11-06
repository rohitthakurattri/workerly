module Bookings
  # What the customer owes, computed only from revisions the customer approved (booking_approvals).
  # A revision the worker sent but the customer hasn't approved never counts, so no path can
  # charge more than was agreed. Stored on bookings.approved_total_minor after every change.
  #
  #   fixed:       approved initial quote + approved change orders
  #   inspection:  approved visit fee, or once the final price is approved:
  #                the larger of final and fee when the fee is taken off the bill (default),
  #                or final + fee — plus approved change orders
  #   closed after inspection, or cancelled after the worker checked in: the visit fee only
  #   cancelled before check-in: nothing
  module AmountDue
    module_function

    LABOUR_TYPES = %w[labour inspection].freeze
    Breakdown = Data.define(:total_minor, :tax_minor, :labour_minor, :revisions)

    def call(booking) = breakdown(booking).total_minor

    # The approved revisions that make up the bill, with their totals, tax and labour (the
    # commission base: labour lines and the visit fee, never parts or travel).
    def breakdown(booking)
      revisions = counted_revisions(booking)
      Breakdown.new(
        total_minor: revisions.sum(&:total_minor), tax_minor: revisions.sum(&:tax_minor),
        labour_minor: revisions.sum { |r| r.items.select { |i| LABOUR_TYPES.include?(i.item_type) }.sum(&:amount_minor) },
        revisions:
      )
    end

    def counted_revisions(booking)
      approved = BookingApproval.approved.where(booking_id: booking.id).includes(quotation_revision: :items).map(&:quotation_revision)
      by = ->(stage) { approved.select { |r| r.stage == stage } }
      fee = by.("inspection_fee")

      return booking.checked_in_at && booking.kind == "inspection" ? fee : [] if booking.cancelled?
      return fee if booking.closed_after_inspection?

      base =
        if booking.kind == "fixed"
          by.("initial")
        elsif (final = by.("final")).any?
          if Workerly.config.inspection_fee_adjusted
            final.sum(&:total_minor) >= fee.sum(&:total_minor) ? final : fee
          else
            fee + final
          end
        else
          fee
        end
      base + by.("change_order")
    end
  end
end
