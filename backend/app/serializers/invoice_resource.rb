class InvoiceResource
  include Alba::Resource

  attribute(:id) { |i| i.public_id }
  attributes :number, :lines, :parties
  attribute(:booking_id) { |i| i.booking.public_id }
  attribute(:issued_at) { |i| i.issued_at.iso8601 }
  attribute(:subtotal) { |i| Shared::Money.to_h(i.subtotal_minor, i.currency_code) }
  attribute(:tax) { |i| Shared::Money.to_h(i.tax_minor, i.currency_code) }
  attribute(:total) { |i| Shared::Money.to_h(i.total_minor, i.currency_code) }
end
