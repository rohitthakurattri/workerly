class RequestInvitation < ApplicationRecord
  has_public_id
  belongs_to :service_request
  belongs_to :worker_profile
  has_one :quotation, dependent: :restrict_with_error, inverse_of: :invitation

  validates :rank, numericality: { only_integer: true, greater_than: 0 }
  validates :distance_m, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :decline_reason, length: { maximum: 300 }

  # Requests still accepting quotes, not declined by this worker: the worker's live leads.
  scope :live, -> { where(declined_at: nil).joins(:service_request).merge(ServiceRequest.where(status: ServiceRequest::QUOTABLE_STATUSES)) }

  def declined? = declined_at.present?
end
