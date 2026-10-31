module Admin
  class ServiceRequestSummaryResource
    include Alba::Resource

    attribute(:id) { |r| r.public_id }
    attributes :status, :urgency, :invited_count, :safety_flag
    attribute(:category) { |r| r.service_category.slug }
    attribute(:city) { |r| r.city.slug }
    attribute(:locality) { |r| r.address_snapshot["locality"] }
    attribute(:customer) { |r| { name: r.customer.name, phone: r.customer.phone_e164 } }
    attribute(:submitted_at) { |r| r.submitted_at.iso8601 }
    attribute(:matched_at) { |r| r.matched_at&.iso8601 }
    attribute(:expires_at) { |r| r.expires_at.iso8601 }
  end
end
