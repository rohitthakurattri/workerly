class UserRole < ApplicationRecord
  belongs_to :user
  belongs_to :granted_by, class_name: "User", optional: true

  validates :role, inclusion: { in: User::ROLES }, uniqueness: { scope: :user_id }
end
