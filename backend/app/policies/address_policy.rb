class AddressPolicy < ApplicationPolicy
  def index? = customer?
  def create? = customer?
  def update? = own?
  def destroy? = own?

  class Scope < Scope
    def resolve = auth&.role == "customer" ? scope.kept.where(user_id: auth.user.id) : scope.none
  end

  private

  def customer? = role == "customer"
  def own? = customer? && record.user_id == user.id && record.deleted_at.nil?
end
