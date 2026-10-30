class City < ApplicationRecord
  include GeoPoint
  include I18nName

  belongs_to :state
  has_many :worker_service_areas, dependent: :restrict_with_error
  has_many :addresses, dependent: :restrict_with_error

  geo_point :center
  i18n_attribute :name_i18n
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :currency_code, :time_zone, :center, presence: true

  scope :launched, -> { where(launched: true) }

  # The nearest launched city whose service radius covers the point, if any.
  def self.for_point(point)
    launched
      .where("ST_DWithin(center, ?::geography, service_radius_m)", point.as_text)
      .order(Arel.sql(sanitize_sql([ "ST_Distance(center, ?::geography)", point.as_text ])))
      .first
  end

  # Straight-line distance in metres from the city centre (PostGIS, on the spheroid).
  def distance_to_m(point)
    self.class.connection.select_value(
      self.class.sanitize_sql([ "SELECT ST_Distance(?::geography, ?::geography)", center.as_text, point.as_text ])
    ).to_f
  end
end
