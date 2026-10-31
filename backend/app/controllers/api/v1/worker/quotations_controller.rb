module Api
  module V1
    module Worker
      class QuotationsController < BaseController
        QUOTE_PARAMS = [ :kind, :notes, :estimated_minutes, :inspection_fee_minor, :valid_until,
                         { items: %i[type description brand quantity unit unit_price_minor condition warranty_days] } ].freeze

        # GET /api/v1/worker/quotations?filter[status]=submitted|accepted|declined|withdrawn|expired — newest first.
        def index
          authorize [ :worker, Quotation ]
          scope = self.scope
          status = params.dig(:filter, :status)
          if status.present?
            raise ApplicationError.new(:invalid_filter, status: :bad_request, details: { allowed: Quotation::STATUSES }) unless Quotation::STATUSES.include?(status)

            scope = scope.where(status:)
          end
          records, meta = paginate(scope, order: { id: :desc })
          render_data(records.map { |q| WorkerQuotationResource.new(q).to_h }, meta:)
        end

        # GET /api/v1/worker/quotations/:id
        def show
          quotation = find_quotation
          authorize [ :worker, quotation ]
          render_data(WorkerQuotationResource.new(quotation).to_h)
        end

        # POST /api/v1/worker/leads/:lead_id/quotations — first quote on a lead.
        def create
          authorize :lead, :quote?
          invitation = current_profile.invitations.live.find_by!(service_requests: { public_id: params[:lead_id] })
          quotation = Quotations::Create.call(invitation:, params: quote_params, actor: current_user)
          render_data(WorkerQuotationResource.new(find_quotation(quotation.public_id)).to_h, status: :created)
        end

        # PATCH /api/v1/worker/quotations/:id — a new revision (send the whole quote again).
        def update
          quotation = find_quotation
          authorize [ :worker, quotation ]
          Quotations::Revise.call(quotation:, params: quote_params, actor: current_user)
          render_data(WorkerQuotationResource.new(find_quotation).to_h)
        end

        # POST /api/v1/worker/quotations/:id/withdraw
        def withdraw
          quotation = find_quotation
          authorize [ :worker, quotation ]
          Quotations::Withdraw.call(quotation:)
          render_data(WorkerQuotationResource.new(quotation).to_h)
        end

        private

        def scope
          policy_scope([ :worker, Quotation ]).includes(:booking, revisions: :items, service_request: :service_category)
        end

        def find_quotation(id = params[:id]) = scope.find_by!(public_id: id)

        def quote_params = params.permit(*QUOTE_PARAMS).to_h
      end
    end
  end
end
