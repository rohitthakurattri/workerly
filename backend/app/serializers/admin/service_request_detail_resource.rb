module Admin
  class ServiceRequestDetailResource
    include Alba::Resource

    attribute(:id) { |r| r.public_id }
    attributes :status, :urgency, :description, :answers, :ai_summary, :safety_flag, :category_source,
               :invited_count, :cancel_reason, :address_snapshot
    attribute(:category) { |r| r.service_category.slug }
    attribute(:city) { |r| r.city.slug }
    attribute(:location) { |r| { lat: r.location_lat, lng: r.location_lng } }
    attribute(:customer) { |r| { id: r.customer.public_id, name: r.customer.name, phone: r.customer.phone_e164 } }
    attribute(:photos) { |r| r.photos.map { |a| RequestAttachmentResource.new(a).to_h } }
    attribute(:preferred_from) { |r| r.preferred_from&.iso8601 }
    attribute(:preferred_to) { |r| r.preferred_to&.iso8601 }
    attribute(:submitted_at) { |r| r.submitted_at.iso8601 }
    attribute(:matched_at) { |r| r.matched_at&.iso8601 }
    attribute(:expires_at) { |r| r.expires_at.iso8601 }
    attribute(:cancelled_at) { |r| r.cancelled_at&.iso8601 }
    # Why each worker got it, and what they did with it.
    attribute(:invitations) do |r|
      r.invitations.includes(worker_profile: :user).map do |i|
        { rank: i.rank, score: i.rank_score.to_f, distance_m: i.distance_m, worker_id: i.worker_profile.public_id,
          worker_name: i.worker_profile.user.name, notified_at: i.notified_at&.iso8601, notified_via: i.notified_via,
          viewed_at: i.viewed_at&.iso8601, declined_at: i.declined_at&.iso8601, decline_reason: i.decline_reason }
      end
    end
  end
end
