module Admin
  # Headless: AI triage quality report. Admin only (it shows model and prompt details).
  class AiQualityPolicy < ApplicationPolicy
    def show? = staff_role?(:admin)
  end
end
