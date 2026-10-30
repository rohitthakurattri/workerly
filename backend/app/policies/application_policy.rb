# Default deny. `auth` is Identity::Authenticate::Current (user + session + active role),
# so policies decide on the role the caller is acting as, not every role they hold.
class ApplicationPolicy
  attr_reader :auth, :record

  def initialize(auth, record)
    @auth = auth
    @record = record
  end

  def user = auth&.user
  def role = auth&.role

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
end
