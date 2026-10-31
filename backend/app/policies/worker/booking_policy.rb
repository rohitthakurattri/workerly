module Worker
  # Jobs the worker won. A suspended worker loses access to customers' contact details.
  class BookingPolicy < ApplicationPolicy
    def index? = worker_in_good_standing?
    def show? = worker_in_good_standing? && record.worker_profile_id == user.worker_profile.id

    class Scope < ApplicationPolicy::Scope
      def resolve
        profile = auth&.role == "worker" && auth.user.worker_profile
        profile ? scope.where(worker_profile_id: profile.id) : scope.none
      end
    end

    private

    def worker_in_good_standing?
      return deny(:role_required) unless role == "worker"

      profile = user.worker_profile
      return deny(:worker_not_registered) unless profile
      return deny(:worker_suspended) if profile.suspended?

      true
    end
  end
end
