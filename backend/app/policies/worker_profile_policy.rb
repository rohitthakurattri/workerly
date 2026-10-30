# A worker acting on their own profile.
class WorkerProfilePolicy < ApplicationPolicy
  def show? = own?
  def update? = own?
  def submit? = own? && (record.editable? || deny(:profile_locked))
  def update_documents? = own? && (record.editable? || deny(:profile_locked))
  def set_availability? = own? && (record.can_receive_leads? || deny(:worker_not_verified))

  private

  def own? = role == "worker" && record.user_id == user.id
end
