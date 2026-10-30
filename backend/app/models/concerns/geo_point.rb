# lat/lng accessors over a geography(Point, 4326) column. RGeo stores (x, y) = (lng, lat).
module GeoPoint
  extend ActiveSupport::Concern

  FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)

  def self.point(lat:, lng:) = FACTORY.point(lng.to_f, lat.to_f)

  class_methods do
    def geo_point(column)
      define_method(:"#{column}_lat") { public_send(column)&.y }
      define_method(:"#{column}_lng") { public_send(column)&.x }
      validate do
        value = public_send(column)
        next if value.nil?
        errors.add(column, "latitude out of range") unless value.y.between?(-90, 90)
        errors.add(column, "longitude out of range") unless value.x.between?(-180, 180)
      end
    end
  end
end
