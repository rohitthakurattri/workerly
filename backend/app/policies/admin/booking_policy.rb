module Admin
  # Support and admins follow bookings, read the chat when helping, and can cancel a stuck booking.
  class BookingPolicy < ApplicationPolicy
    def index? = staff_role?(:admin, :support)
    def show? = index?
    def cancel? = index?

    class Scope < ApplicationPolicy::Scope
      def resolve = scope.all
    end
  end
end
