# A customer acting on their own requests. Other customers' requests are invisible (scope), so
# they surface as 404, never 403.
class ServiceRequestPolicy < ApplicationPolicy
  def index? = customer?
  def create? = customer?
  def show? = own?
  def update? = own? && (record.draft? || deny(:request_locked))
  def destroy? = update?
  def submit? = own?
  def cancel? = own? && (record.cancellable? || deny(:request_not_cancellable))

  class Scope < Scope
    def resolve = auth&.role == "customer" ? scope.where(customer_id: auth.user.id) : scope.none
  end

  private

  def customer? = role == "customer"
  def own? = customer? && record.customer_id == user.id
end
