module Customer
  class PaymentPolicy < ApplicationPolicy
    def show? = role == "customer" && record.booking.customer_id == user.id
    def verify? = show?

    class Scope < ApplicationPolicy::Scope
      def resolve = auth&.role == "customer" ? scope.joins(:booking).where(bookings: { customer_id: auth.user.id }) : scope.none
    end
  end
end
