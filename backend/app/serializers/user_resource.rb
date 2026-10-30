class UserResource
  include Alba::Resource

  attribute(:id) { |u| u.public_id }
  attributes :name, :email, :locale
  attribute(:phone) { |u| u.phone_e164 }
  attribute(:roles) { |u| u.roles.sort }
  attribute(:created_at) { |u| u.created_at.iso8601 }
end
