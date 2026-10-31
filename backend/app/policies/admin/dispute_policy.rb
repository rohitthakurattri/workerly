module Admin
  class DisputePolicy < ApplicationPolicy
    def index? = staff_role?(:admin, :support)
    def show? = index?
    def resolve? = index?

    class Scope < ApplicationPolicy::Scope
      def resolve = scope.all
    end
  end
end
