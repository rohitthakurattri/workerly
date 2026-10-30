class Address < ApplicationRecord
  include GeoPoint

  MAX_PER_USER = 10

  has_public_id
  belongs_to :user
  belongs_to :city
  has_many :service_requests, dependent: :restrict_with_error

  geo_point :location
  validates :location, presence: true
  validates :line1, presence: true, length: { maximum: 200 }
  validates :line2, length: { maximum: 200 }
  validates :landmark, length: { maximum: 120 }
  validates :locality, presence: true, length: { maximum: 120 }
  validates :label, length: { maximum: 40 }
  validates :pincode, format: { with: /\A[1-9]\d{5}\z/, message: "must be a 6-digit PIN code" }
  validate :city_is_launched

  scope :kept, -> { where(deleted_at: nil) }

  before_validation :assign_city, if: -> { location_changed? || city.nil? }
  before_validation { self.pincode = pincode.to_s.gsub(/\s/, "") }

  # What a submitted request keeps, independent of later edits to the address book.
  def snapshot
    { label:, line1:, line2:, landmark:, locality:, pincode: }.stringify_keys
  end

  def soft_delete! = update!(deleted_at: Time.current, is_default: false)

  private

  # The city is derived from the pin, so a customer can't attach a Delhi pin to Mohali.
  def assign_city
    self.city = City.for_point(location) if location
  end

  def city_is_launched
    errors.add(:location, :outside_service_area, message: "is outside the areas Workerly serves") if location && city.nil?
    errors.add(:city, "is not open for Workerly yet") if city && !city.launched?
  end
end
