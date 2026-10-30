class WorkerServiceAreaResource
  include Alba::Resource

  attribute(:id) { |a| a.public_id }
  attributes :label, :radius_m
  attribute(:city) { |a| a.city.slug }
  attribute(:center) { |a| { lat: a.center_lat, lng: a.center_lng } }
end
