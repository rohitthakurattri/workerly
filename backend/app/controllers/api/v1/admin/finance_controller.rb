module Api
  module V1
    module Admin
      class FinanceController < BaseController
        include Idempotent

        idempotent :create_payout

        # GET /api/v1/admin/finance/balances — workers Workerly holds money for, or who owe commission.
        def balances
          authorize :"admin/finance", :index?
          workers = WorkerProfile.where(id: Ledger::Account.where(owner_type: "WorkerProfile").select(:owner_id)).includes(:user)
          rows = workers.map do |w|
            b = Payouts::Balance.call(w)
            { worker_id: w.public_id, name: w.user.name, phone: w.user.phone_e164,
              held: Shared::Money.to_h(b.payable_minor, b.currency), owed: Shared::Money.to_h(b.owed_minor, b.currency),
              net: Shared::Money.to_h(b.net_minor, b.currency) }
          end
          render_data(rows.sort_by { |r| -r[:net][:minor] })
        end

        # POST /api/v1/admin/finance/payouts { worker_id, amount_minor, reference } + Idempotency-Key
        def create_payout
          authorize :"admin/finance", :payout?
          worker = WorkerProfile.find_by!(public_id: params.require(:worker_id))
          payout = Payouts::Create.call(worker:, amount_minor: params.require(:amount_minor), reference: params[:reference], auth: current_auth)
          render_data({ id: payout.public_id, amount: Shared::Money.to_h(payout.amount_minor, payout.currency_code), reference: payout.provider_ref,
                        balance: Payouts::Balance.call(worker).to_h }, status: :created)
        end

        # GET /api/v1/admin/finance/reconciliation?from=…&to=… (default: last 24 h)
        def reconciliation
          authorize :"admin/finance", :reconcile?
          to = parse_time(params[:to]) || Time.current
          from = parse_time(params[:from]) || (to - 1.day)
          render_data(Finance::Reconciliation.call(from:, to:))
        end

        # GET /api/v1/admin/finance/commission_rules
        def commission_rules
          authorize :"admin/finance", :manage_commission?
          render_data(CommissionRule.includes(:city, :service_category).order(effective_from: :desc).map { |r| serialize_rule(r) })
        end

        # POST /api/v1/admin/finance/commission_rules { city?, category?, percent_bps, fixed_minor?, effective_from? }
        # Rules are never edited; a new rule with a later effective_from replaces the old one. Audited.
        def create_commission_rule
          authorize :"admin/finance", :manage_commission?
          rule = CommissionRule.transaction do
            CommissionRule.create!(
              city: params[:city].presence && City.find_by!(slug: params[:city]),
              service_category: params[:category].presence && ServiceCategory.find_by!(slug: params[:category]),
              percent_bps: params.require(:percent_bps), fixed_minor: params[:fixed_minor] || 0,
              effective_from: parse_time(params[:effective_from]) || Time.current, created_by: current_user
            ).tap { |r| ::Admin::Audit.record!(action: "commission_rule.created", target: r, changes: r.slice(:percent_bps, :fixed_minor)) }
          end
          render_data(serialize_rule(rule), status: :created)
        end

        private

        def serialize_rule(r)
          { id: r.id, city: r.city&.slug, category: r.service_category&.slug, percent_bps: r.percent_bps,
            fixed_minor: r.fixed_minor, effective_from: r.effective_from.iso8601 }
        end

        def parse_time(value)
          value.present? ? Time.zone.iso8601(value.to_s) : nil
        rescue ArgumentError
          raise ApplicationError.new(:validation_failed, details: { field_errors: { "time" => [ "is not a valid ISO 8601 time" ] } })
        end
      end
    end
  end
end
