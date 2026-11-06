module Admin
  # Headless: payouts, worker balances, reconciliation and commission rules.
  class FinancePolicy < ApplicationPolicy
    def index? = staff_role?(:admin, :finance)
    def payout? = index?
    def reconcile? = index?
    def manage_commission? = index?
  end
end
