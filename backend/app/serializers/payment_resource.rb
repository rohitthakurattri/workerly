class PaymentResource
  include Alba::Resource

  attribute(:id) { |p| p.public_id }
  attributes :method, :provider, :status
  attribute(:amount) { |p| Shared::Money.to_h(p.amount_minor, p.currency_code) }
  attribute(:refunded) { |p| Shared::Money.to_h(p.refunded_minor, p.currency_code) }
  attribute(:captured_at) { |p| p.captured_at&.iso8601 }
  attribute(:created_at) { |p| p.created_at.iso8601 }
end
