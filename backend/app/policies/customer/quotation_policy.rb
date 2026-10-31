module Customer
  # Quotes on the customer's own requests. Others' quotes are outside the scope (404). Withdrawn
  # quotes are gone for the customer.
  class QuotationPolicy < ApplicationPolicy
    def index? = role == "customer"
    def show? = own?
    def accept? = own?
    def decline? = own?

    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless auth&.role == "customer"

        scope.joins(:service_request).where(service_requests: { customer_id: auth.user.id }).where.not(status: "withdrawn")
      end
    end

    private

    def own? = role == "customer" && record.service_request.customer_id == user.id
  end
end
