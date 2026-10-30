module Workers
  # A logged-in customer becomes a worker: grants the role and opens a draft profile.
  module Register
    module_function

    def call(user:)
      User.transaction do
        user.lock!
        raise ApplicationError.new(:already_registered, status: :conflict) if user.worker_profile
        raise ApplicationError.new(:name_required, details: { field_errors: { name: [ "is required" ] } }) if user.name.blank?

        user.grant_role!(:worker)
        user.create_worker_profile!
      end
    end
  end
end
