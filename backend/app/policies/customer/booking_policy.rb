module Customer
  class BookingPolicy < ApplicationPolicy
    def index? = role == "customer"
    def show? = role == "customer" && record.customer_id == user.id

    class Scope < ApplicationPolicy::Scope
      def resolve = auth&.role == "customer" ? scope.where(customer_id: auth.user.id) : scope.none
    end
  end
end
