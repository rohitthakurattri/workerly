class NotificationResource
  include Alba::Resource

  attribute(:id) { |n| n.public_id }
  attributes :kind, :title, :body, :url, :data
  attribute(:read) { |n| n.read_at.present? }
  attribute(:created_at) { |n| n.created_at.iso8601 }
end
