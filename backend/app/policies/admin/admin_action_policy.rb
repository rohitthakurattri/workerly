module Admin
  class AdminActionPolicy < ApplicationPolicy
    def index? = staff_role?(:admin)
  end
end
