# Default deny. `auth` is Identity::Authenticate::Current (user + session + active role),
# so policies decide on the role the caller is acting as, not every role they hold.
class ApplicationPolicy
  attr_reader :auth, :record
  # Optional machine-readable reason, rendered as the error code when a check fails.
  attr_reader :denial_reason

  def initialize(auth, record)
    @auth = auth
    @record = record
  end

  def user = auth&.user
  def role = auth&.role
  def staff_role?(*roles) = !!auth&.session&.staff? && roles.map(&:to_s).include?(role)

  def index? = false
  def show? = false
  def create? = false
  def update? = false
  def destroy? = false

  class Scope
    attr_reader :auth, :scope

    def initialize(auth, scope)
      @auth = auth
      @scope = scope
    end

    def resolve = scope.none
  end

  private

  def deny(reason)
    @denial_reason = reason
    false
  end
end
