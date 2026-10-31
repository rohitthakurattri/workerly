module Admin
  # Support and admins watch live requests (no quotes yet, nobody matched), their quotes, and help customers.
  class ServiceRequestPolicy < ApplicationPolicy
    def index? = staff_role?(:admin, :support)
    def show? = index?

    class Scope < ApplicationPolicy::Scope
      def resolve = scope.where.not(status: "draft")
    end
  end
end
