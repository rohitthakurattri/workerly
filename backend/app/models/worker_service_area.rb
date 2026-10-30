class WorkerServiceArea < ApplicationRecord
  include GeoPoint

  RADIUS_RANGE = 500..50_000

  has_public_id
  belongs_to :worker_profile
  belongs_to :city

  geo_point :center
  validates :center, presence: true
  validates :radius_m, numericality: { only_integer: true, in: RADIUS_RANGE }
  validates :label, length: { maximum: 60 }
  validate :city_is_launched
  validate :center_inside_city

  private

  def city_is_launched
    errors.add(:city, "is not open for Workerly yet") if city && !city.launched?
  end

  def center_inside_city
    return unless city && center
    return if city.distance_to_m(center) <= city.service_radius_m

    errors.add(:center, "must be within #{city.service_radius_m / 1000} km of #{city.name('en')}")
  end
end
