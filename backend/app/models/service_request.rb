class ServiceRequest < ApplicationRecord
  include GeoPoint

  STATUSES = %w[draft open quoting booked fulfilled expired cancelled].freeze
  # Waiting for or receiving quotes, or booked: counts towards the customer's limit.
  ACTIVE_STATUSES = %w[open quoting booked].freeze
  CANCELLABLE_STATUSES = %w[open quoting].freeze
  # Workers can see and quote on these.
  QUOTABLE_STATUSES = %w[open quoting].freeze
  URGENCIES = %w[asap today this_week flexible].freeze
  MAX_PHOTOS = 6
  MAX_DRAFTS = 5
  MAX_ACTIVE = 5
  DESCRIPTION_MIN = 10

  has_public_id
  belongs_to :customer, class_name: "User"
  belongs_to :service_category, optional: true
  belongs_to :address, optional: true
  belongs_to :city, optional: true
  belongs_to :triage_analysis, class_name: "AiAnalysis", optional: true
  has_many :attachments, -> { order(:created_at, :id) }, class_name: "RequestAttachment", dependent: :destroy
  has_many :ai_analyses, as: :analysable, dependent: :restrict_with_error
  has_many :invitations, -> { order(:rank) }, class_name: "RequestInvitation", dependent: :restrict_with_error
  has_many :quotations, dependent: :restrict_with_error
  has_many :bookings, dependent: :restrict_with_error

  geo_point :location
  validates :status, inclusion: { in: STATUSES }
  validates :urgency, inclusion: { in: URGENCIES }
  validates :description, length: { maximum: 2000 }
  validates :cancel_reason, length: { maximum: 500 }
  validate :answers_shape
  validate :preferred_window
  validate :category_is_available, if: :service_category_id_changed?
  validate :address_belongs_to_customer, if: :address_id_changed?

  before_save :record_category_source, if: :service_category_id_changed?

  scope :active, -> { where(status: ACTIVE_STATUSES) }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def cancellable? = CANCELLABLE_STATUSES.include?(status)
  def quotable?(now = Time.current) = QUOTABLE_STATUSES.include?(status) && expires_at.present? && expires_at > now
  def active_booking = bookings.active.first

  def photos = attachments.select { |a| a.kind == "image" }

  # What a draft still needs before it can be submitted (mirrors the steps in the customer app).
  def missing
    missing = []
    missing << "description" if description.to_s.strip.length < DESCRIPTION_MIN
    missing << "category" if service_category.nil?
    missing << "address" if address.nil? || address.deleted_at
    missing
  end

  private

  def answers_shape
    list = answers.is_a?(Array) ? answers : nil
    valid = list && list.size <= 10 && list.all? do |a|
      a.is_a?(Hash) && a["question"].is_a?(String) && a["answer"].is_a?(String) &&
        a["question"].length <= 300 && a["answer"].length <= 500
    end
    errors.add(:answers, "must be up to 10 { question, answer } pairs") unless valid
  end

  def preferred_window
    return unless preferred_from || preferred_to
    return errors.add(:preferred_to, "must be after the start") if preferred_from && preferred_to && preferred_to <= preferred_from
    return unless will_save_change_to_preferred_from? && preferred_from

    errors.add(:preferred_from, "can't be in the past") if preferred_from < 1.hour.ago
    errors.add(:preferred_from, "must be within the next 30 days") if preferred_from > 30.days.from_now
  end

  def category_is_available
    return if service_category.nil?

    errors.add(:service_category, "is not available") unless service_category.active? && service_category.deleted_at.nil?
  end

  def address_belongs_to_customer
    return if address.nil?

    errors.add(:address, "not found") if address.user_id != customer_id || address.deleted_at
  end

  # Did the customer keep the AI's suggestion? Feeds the Phase 8 accuracy test set.
  def record_category_source
    return self.category_source = nil if service_category_id.nil?

    suggested = triage_analysis&.suggested_category_id
    self.category_source = suggested && suggested == service_category_id ? "ai" : "customer"
  end
end
