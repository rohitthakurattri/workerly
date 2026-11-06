module Invoices
  # One invoice per booking once it's fully paid, numbered without gaps per financial year
  # (WK/2026-27/000001). Lines are the approved revisions that make up the bill. Tax treatment
  # is configurable per category and stays 0 until the CA's GST opinion.
  module Issue
    module_function

    def call(booking, now: Time.current)
      return booking.invoice if booking.invoice

      due = Bookings::AmountDue.breakdown(booking)
      request = booking.service_request
      lines = due.revisions.flat_map do |rev|
        rev.items.map do |i|
          { stage: rev.stage, type: i.item_type, description: i.description, quantity: i.quantity.to_f, unit: i.unit,
            unit_price_minor: i.unit_price_minor, amount_minor: i.amount_minor }
        end
      end
      Invoice.create!(
        booking:, number: next_number(now), issued_at: now, currency_code: booking.currency_code,
        subtotal_minor: due.total_minor - due.tax_minor, tax_minor: due.tax_minor, total_minor: due.total_minor, lines:,
        parties: { worker: { name: booking.worker_profile.user.name }, customer: { name: booking.customer.name },
                   address: request.address_snapshot.slice("line1", "line2", "locality", "pincode").merge("city" => request.city.slug),
                   service: request.service_category.name(:en),
                   payments: booking.payments.settled.map { |p| { method: p.method, amount_minor: p.amount_minor, at: p.captured_at&.iso8601 } } }
      )
    end

    def next_number(now)
      local = now.in_time_zone("Asia/Kolkata")
      start = local.month >= 4 ? local.year : local.year - 1
      series = "#{Workerly.config.invoice_prefix}/#{start}-#{(start + 1).to_s[-2..]}"
      "#{series}/#{format('%06d', InvoiceSequence.next!(series))}"
    end
  end
end
