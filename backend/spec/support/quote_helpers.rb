module QuoteHelpers
  FIXED = { kind: "fixed", estimated_minutes: 60, notes: "Replace the tap cartridge.",
            items: [ { type: "labour", description: "Fix kitchen tap", quantity: 1, unit: "job", unit_price_minor: 50_000 },
                     { type: "material", description: "Tap cartridge", brand: "Jaquar", quantity: 1, unit: "item",
                       unit_price_minor: 45_000, condition: "new", warranty_days: 180 } ] }.freeze

  # An open request in Mohali with `workers` matched, invited plumbers (matching runs inline).
  def matched_request(workers: 2, customer: create(:user))
    profiles = (1..workers).map { |i| create(:worker_profile, :matchable, lat: 30.70 + (i * 0.001)) }
    request = create(:service_request, :ready, customer:)
    perform_enqueued_jobs(only: Matching::MatchRequestJob) { Requests::Submit.call(request:) }
    [ request.reload, profiles ]
  end

  def quote!(profile, request, params = FIXED)
    invitation = profile.invitations.find_by!(service_request: request)
    Quotations::Create.call(invitation:, params: params.deep_stringify_keys.with_indifferent_access, actor: profile.user)
  end

  def fixed_quote(amount_minor) = FIXED.merge(items: [ { type: "labour", description: "Labour", quantity: 1, unit: "job", unit_price_minor: amount_minor } ])
end

RSpec.configure { |c| c.include QuoteHelpers }
