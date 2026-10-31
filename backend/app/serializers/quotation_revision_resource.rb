class QuotationRevisionResource
  include Alba::Resource

  attribute(:id) { |r| r.public_id }
  attributes :version, :stage, :tax_rate_bps, :notes, :estimated_minutes
  attribute(:subtotal) { |r| Shared::Money.to_h(r.subtotal_minor, r.currency_code) }
  attribute(:tax) { |r| Shared::Money.to_h(r.tax_minor, r.currency_code) }
  attribute(:total) { |r| Shared::Money.to_h(r.total_minor, r.currency_code) }
  attribute(:items) do |r|
    r.items.map do |i|
      { type: i.item_type, description: i.description, brand: i.brand, quantity: i.quantity.to_f, unit: i.unit,
        unit_price: Shared::Money.to_h(i.unit_price_minor, r.currency_code), amount: Shared::Money.to_h(i.amount_minor, r.currency_code),
        condition: i.condition, warranty_days: i.warranty_days }
    end
  end
  attribute(:created_at) { |r| r.created_at.iso8601 }
end
