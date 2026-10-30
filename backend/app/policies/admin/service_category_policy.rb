module Admin
  class ServiceCategoryPolicy < ApplicationPolicy
    def index? = staff_role?(:admin, :verifier, :support, :finance)
    def create? = staff_role?(:admin)
    def update? = staff_role?(:admin)
  end
end
