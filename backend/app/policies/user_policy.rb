class UserPolicy < ApplicationPolicy
  def show? = record == user
  def update? = record == user
end
