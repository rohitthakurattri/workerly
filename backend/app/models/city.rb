class City < ApplicationRecord
  include GeoPoint
  include I18nName

  belongs_to :state
  has_many :worker_service_areas, dependent: :restrict_with_error

  geo_point :center
  i18n_attribute :name_i18n
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :currency_code, :time_zone, :center, presence: true

  scope :launched, -> { where(launched: true) }

  # Straight-line distance in metres from the city centre (PostGIS, on the spheroid).
  def distance_to_m(point)
    self.class.connection.select_value(
      self.class.sanitize_sql([ "SELECT ST_Distance(?::geography, ?::geography)", center.as_text, point.as_text ])
    ).to_f
  end
end
