class CustomerBookingResource < BookingResource
  attribute(:worker) do |b|
    card = QuotationResource::WorkerCard.call(b.worker_profile)
    b.contact_visible? ? card.merge(phone: b.worker_profile.user.phone_e164) : card
  end
  attribute(:can_review) { |b| b.review.nil? && b.done? && b.completed_at >= Workerly.config.review_window_days.days.ago }
  attribute(:can_dispute) do |b|
    b.open_dispute.nil? && %w[completed paid].include?(b.status) && b.completed_at >= Workerly.config.dispute_window_days.days.ago
  end

  private

  def viewer_role = "customer"
end
