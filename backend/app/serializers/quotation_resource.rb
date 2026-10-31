# A quote as the customer compares it: the price and its breakdown, plus who the worker is.
# Never the worker's phone before booking.
class QuotationResource
  include Alba::Resource

  attribute(:id) { |q| q.public_id }
  attributes :kind, :current_version
  attribute(:status) { |q| q.effective_status }
  attribute(:valid_until) { |q| q.valid_until.iso8601 }
  attribute(:submitted_at) { |q| q.created_at.iso8601 }
  attribute(:revised) { |q| q.current_version > 1 }
  attribute(:revision) { |q| QuotationRevisionResource.new(q.current_revision).to_h }
  attribute(:worker) { |q| WorkerCard.call(q.worker_profile) }
  attribute(:distance_band) { |q| Matching::DistanceBand.call(q.invitation.distance_m) }
  attribute(:booking_id) { |q| q.accepted? ? q.booking&.public_id : nil }
  attribute(:decline_reason) { |q| q.declined? && q.decline_reason != "another_accepted" ? q.decline_reason : nil }

  # Shared with the booking views. jobs_done counts completed bookings (Phase 6 starts completing them).
  module WorkerCard
    def self.call(p)
      { id: p.public_id, name: p.user.name, photo: FileResource.call(p.photo), rating_avg: p.rating_avg&.to_f,
        rating_count: p.rating_count, experience_years: p.experience_years, verified: p.approved?,
        jobs_done: p.bookings.where(status: %w[completed paid]).count }
    end
  end
end
