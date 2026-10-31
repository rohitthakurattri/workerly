module Worker
  # A worker's own quotes. Changing a quote needs the same standing as seeing leads (approved,
  # not suspended); reading past quotes only needs the worker role.
  class QuotationPolicy < ApplicationPolicy
    def index? = role == "worker"
    def show? = own?
    def update? = own? && LeadPolicy.new(auth, :lead).quote?
    def withdraw? = update?

    class Scope < ApplicationPolicy::Scope
      def resolve
        profile = auth&.role == "worker" && auth.user.worker_profile
        profile ? scope.where(worker_profile_id: profile.id) : scope.none
      end
    end

    private

    def own? = role == "worker" && record.worker_profile_id == user.worker_profile&.id
  end
end
