require "rails_helper"

RSpec.describe Quotations::Build do
  let(:request) { create(:service_request, :ready).tap { |r| r.update_columns(city_id: create(:mohali).id) } }
  let(:actor) { create(:user) }

  def build(params) = described_class.call(params: params.deep_stringify_keys.with_indifferent_access, request:, actor:, version: 1)

  def errors_for(params)
    build(params)
    raise "expected validation_failed"
  rescue ApplicationError => e
    e.details[:field_errors]
  end

  it "prices every line on the server and totals them" do
    draft = build(QuoteHelpers::FIXED.merge(items: [
      { type: "labour", description: "Labour", quantity: 1, unit: "job", unit_price_minor: 50_000 },
      { type: "material", description: "Pipe", quantity: "2.5", unit: "metre", unit_price_minor: 12_345 }
    ]))
    expect(draft.items.map(&:amount_minor)).to eq([ 50_000, 30_863 ]) # 2.5 × 12,345 = 30,862.5 → half up
    expect(draft.revision).to have_attributes(subtotal_minor: 80_863, tax_minor: 0, total_minor: 80_863, currency_code: "INR", stage: "initial")
  end

  it "applies the category's tax rate, rounded half up" do
    request.service_category.update!(tax_rate_bps: 1800)
    draft = build(fixed_quote(10_003))
    expect(draft.revision).to have_attributes(subtotal_minor: 10_003, tax_rate_bps: 1800, tax_minor: 1801, total_minor: 11_804)
  end

  it "builds an inspection quote from the fee" do
    draft = build(kind: "inspection", inspection_fee_minor: 19_900, notes: "Final price after I see it.")
    expect(draft.items.sole).to have_attributes(item_type: "inspection", unit: "visit", amount_minor: 19_900)
    expect(draft.revision).to have_attributes(stage: "inspection_fee", total_minor: 19_900)
  end

  it "allows a free inspection but not a free fixed job" do
    expect(build(kind: "inspection", inspection_fee_minor: 0).revision.total_minor).to eq(0)
    expect(errors_for(fixed_quote(0))).to include("total")
  end

  it "rejects inspection quotes where the category doesn't allow them" do
    request.service_category.update!(inspection_allowed: false)
    expect { build(kind: "inspection", inspection_fee_minor: 19_900) }.to raise_error(ApplicationError) { |e| expect(e.code).to eq("inspection_not_allowed") }
  end

  it "reports field errors per line" do
    errors = errors_for(kind: "fixed", items: [
      { type: "labour", description: "", quantity: 0, unit: "job", unit_price_minor: 100 },
      { type: "magic", description: "x", quantity: 1, unit: "parsec", unit_price_minor: -5 },
      { type: "inspection", description: "visit", quantity: 1, unit: "visit", unit_price_minor: 100 }
    ])
    expect(errors.keys).to include("items.0.description", "items.0.quantity", "items.1.type", "items.1.unit", "items.1.unit_price_minor", "items.2.type")
  end

  it "needs at least one line, at most 30, and caps the total" do
    expect(errors_for(kind: "fixed", items: [])).to include("items")
    expect(errors_for(kind: "fixed", items: Array.new(31) { fixed_quote(100)[:items].first })).to include("items")
    expect(errors_for(fixed_quote(50_000_001))).to include("total")
    expect(errors_for(kind: "bogus", items: fixed_quote(100)[:items])).to include("kind")
  end

  it "ignores client-sent amounts and masks contact details" do
    draft = build(kind: "fixed", notes: "Call me on 98140 12345", items: [
      { type: "labour", description: "Mail me a@b.co", quantity: 1, unit: "job", unit_price_minor: 100, amount_minor: 1 }
    ])
    expect(draft.items.first.amount_minor).to eq(100)
    expect(draft.revision.notes).to eq("Call me on [phone removed]")
    expect(draft.items.first.description).to eq("Mail me [email removed]")
  end

  it "keeps condition only for materials" do
    draft = build(kind: "fixed", items: [ { type: "labour", description: "x", quantity: 1, unit: "job", unit_price_minor: 100, condition: "used" } ])
    expect(draft.items.first.condition).to be_nil
  end
end
