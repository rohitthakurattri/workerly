module Api
  module V1
    module Admin
      class DisputesController < BaseController
        # GET /api/v1/admin/disputes?filter[status]=open|resolved — oldest open first.
        def index
          authorize [ :admin, Dispute ]
          scope = policy_scope([ :admin, Dispute ]).includes(:raised_by, booking: { worker_profile: :user })
          status = params.dig(:filter, :status).presence || "open"
          raise ApplicationError.new(:invalid_filter, status: :bad_request, details: { allowed: Dispute::STATUSES }) unless Dispute::STATUSES.include?(status)

          records, meta = paginate(scope.where(status:), order: { id: status == "open" ? :asc : :desc })
          render_data(records.map { |d| ::Admin::DisputeResource.new(d).to_h }, meta:)
        end

        # POST /api/v1/admin/disputes/:id/resolve { resolution } — audited; the booking returns to its previous status.
        def resolve
          dispute = policy_scope([ :admin, Dispute ]).find_by!(public_id: params[:id])
          authorize [ :admin, dispute ]
          Disputes::Resolve.call(dispute:, auth: current_auth, resolution: params[:resolution])
          render_data(::Admin::DisputeResource.new(dispute.reload).to_h)
        end
      end
    end
  end
end
