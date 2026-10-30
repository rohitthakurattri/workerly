class CityResource
  include Alba::Resource

  attributes :slug, :currency_code, :time_zone, :service_radius_m
  attribute(:name) { |c| c.name }
  attribute(:state) { |c| c.state.name }
  attribute(:center) { |c| { lat: c.center_lat, lng: c.center_lng } }
end
