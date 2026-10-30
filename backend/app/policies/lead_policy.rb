# Headless: authorize :lead, :index?
# Only approved, unsuspended workers see leads. Phase 4 also limits them to
# requests they were invited to (request_invitations).
class LeadPolicy < ApplicationPolicy
  def index? = can_receive_leads?
  def show? = can_receive_leads?

  private

  def can_receive_leads?
    return deny(:role_required) unless role == "worker"

    profile = user.worker_profile
    return deny(:worker_not_registered) unless profile
    return deny(:worker_suspended) if profile.suspended?

    profile.can_receive_leads? || deny(:worker_not_verified)
  end
end
