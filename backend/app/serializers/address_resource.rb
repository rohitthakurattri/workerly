class AddressResource
  include Alba::Resource

  attribute(:id) { |a| a.public_id }
  attributes :label, :line1, :line2, :landmark, :locality, :pincode, :is_default
  attribute(:city) { |a| a.city.slug }
  attribute(:location) { |a| { lat: a.location_lat, lng: a.location_lng } }
end
