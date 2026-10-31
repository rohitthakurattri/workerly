module BookingHelpers
  INSPECTION = { kind: "inspection", inspection_fee_minor: 19_900 }.freeze

  # A confirmed booking from a real request → quote → accept chain. `rivals` other workers also quote.
  def booked!(kind: "fixed", customer: create(:user), amount_minor: 95_000, rivals: 0)
    request, (winner, *others) = matched_request(workers: 1 + rivals, customer:)
    quote = quote!(winner, request, kind == "inspection" ? INSPECTION : fixed_quote(amount_minor))
    others.each { |w| quote!(w, request, fixed_quote(amount_minor + 10_000)) }
    Quotations::Accept.call(quotation: quote, version: 1, customer:)
  end

  def act!(booking, event, role: nil, params: {}, actor: nil)
    role ||= Bookings::Transitions::RULES.fetch(event)[:roles].first
    actor ||= role == "customer" ? booking.customer : booking.worker_profile.user
    Bookings::Perform.call(booking: booking.reload, event:, actor:, role:, params:)
  end

  def lines(*amounts) = { items: amounts.map { |a| { type: "labour", description: "Work", quantity: 1, unit: "job", unit_price_minor: a } } }
  def soon = 2.hours.from_now.iso8601
end

RSpec.configure { |c| c.include BookingHelpers }
