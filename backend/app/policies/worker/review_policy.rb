module Worker
  class ReviewPolicy < ApplicationPolicy
    def index? = role == "worker"
  end
end
