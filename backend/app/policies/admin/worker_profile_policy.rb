module Admin
  class WorkerProfilePolicy < ApplicationPolicy
    def index? = staff_role?(:admin, :verifier, :support)
    def show? = index?
    def decide? = staff_role?(:admin, :verifier)
    def suspend? = staff_role?(:admin, :support)
    def reinstate? = suspend?

    class Scope < ApplicationPolicy::Scope
      def resolve = scope.kept
    end
  end
end
