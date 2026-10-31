module Customer
  class BookingPolicy < ApplicationPolicy
    def index? = role == "customer"
    def show? = role == "customer" && record.customer_id == user.id
    # State and timing rules are checked by Bookings::Perform, Reviews::Create and Disputes::Open.
    def act? = show?
    def message? = show?
    def review? = show?
    def dispute? = show?

    class Scope < ApplicationPolicy::Scope
      def resolve = auth&.role == "customer" ? scope.where(customer_id: auth.user.id) : scope.none
    end
  end
end
