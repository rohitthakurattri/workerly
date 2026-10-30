class AdminAction < ApplicationRecord
  include AppendOnly

  belongs_to :admin, class_name: "User"
  validates :action, :admin_role, :target_type, :target_id, presence: true
end
