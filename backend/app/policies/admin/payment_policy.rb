module Admin
  # Support can see payments to help customers; only finance and admins move money.
  class PaymentPolicy < ApplicationPolicy
    def index? = staff_role?(:admin, :finance, :support)
    def show? = index?
    def refund? = staff_role?(:admin, :finance)

    class Scope < ApplicationPolicy::Scope
      def resolve = scope.all
    end
  end
end
