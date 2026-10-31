class MessageResource
  include Alba::Resource

  attribute(:id) { |m| m.public_id }
  attributes :sender_role, :body
  attribute(:sender_name) { |m| m.sender.name }
  attribute(:created_at) { |m| m.created_at.iso8601 }
end
