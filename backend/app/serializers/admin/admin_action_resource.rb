module Admin
  class AdminActionResource
    include Alba::Resource

    attributes :id, :action, :admin_role, :target_type, :reason, :request_id
    # params[:target_ids]: { [type, id] => public_id }, resolved in bulk by the controller.
    attribute(:target_id) { |a| params.fetch(:target_ids, {})[[ a.target_type, a.target_id ]] || a.target_id }
    attribute(:changes) { |a| a.changes_made }
    attribute(:admin) { |a| { id: a.admin.public_id, name: a.admin.name, phone: a.admin.phone_e164 } }
    attribute(:ip) { |a| a.ip&.to_s }
    attribute(:at) { |a| a.created_at.iso8601 }
  end
end
