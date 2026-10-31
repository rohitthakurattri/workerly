module Admin
  class BookingSummaryResource
    include Alba::Resource

    attribute(:id) { |b| b.public_id }
    attributes :status, :kind
    attribute(:category) { |b| b.service_request.service_category.slug }
    attribute(:locality) { |b| b.service_request.address_snapshot["locality"] }
    attribute(:customer_name) { |b| b.customer.name }
    attribute(:worker_name) { |b| b.worker_profile.user.name }
    attribute(:approved_total) { |b| Shared::Money.to_h(b.approved_total_minor, b.currency_code) }
    attribute(:confirmed_at) { |b| b.confirmed_at.iso8601 }
    attribute(:scheduled_at) { |b| b.scheduled_at&.iso8601 }
    attribute(:updated_at) { |b| b.updated_at.iso8601 }
  end
end
