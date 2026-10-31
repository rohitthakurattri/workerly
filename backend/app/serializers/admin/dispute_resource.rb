module Admin
  class DisputeResource
    include Alba::Resource

    attribute(:id) { |d| d.public_id }
    attributes :category, :description, :status, :resolution
    attribute(:booking_id) { |d| d.booking.public_id }
    attribute(:booking_status) { |d| d.booking.status }
    attribute(:approved_total) { |d| Shared::Money.to_h(d.booking.approved_total_minor, d.booking.currency_code) }
    attribute(:customer_name) { |d| d.raised_by.name }
    attribute(:worker_name) { |d| d.booking.worker_profile.user.name }
    attribute(:created_at) { |d| d.created_at.iso8601 }
    attribute(:resolved_at) { |d| d.resolved_at&.iso8601 }
  end
end
