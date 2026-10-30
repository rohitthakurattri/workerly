module Api
  module V1
    module Admin
      class WorkersController < BaseController
        STATUSES = WorkerProfile::STATUSES

        # GET /api/v1/admin/workers?filter[status]=pending_review&filter[suspended]=true&q=98765&cursor=…
        # The review queue is oldest-submitted first.
        def index
          authorize [ :admin, WorkerProfile ]
          scope = policy_scope([ :admin, WorkerProfile ]).includes(:user, :service_categories)
          status = params.dig(:filter, :status)
          if status.present?
            raise ApplicationError.new(:invalid_filter, status: :bad_request, details: { allowed: STATUSES }) unless STATUSES.include?(status)

            scope = scope.where(verification_status: status)
          end
          scope = scope.where.not(suspended_at: nil) if params.dig(:filter, :suspended) == "true"
          if params[:q].present?
            q = "%#{WorkerProfile.sanitize_sql_like(params[:q].to_s.strip)}%"
            scope = scope.joins(:user).where("users.name ILIKE :q OR users.phone_e164 LIKE :q", q:)
          end

          order = status == "pending_review" ? { submitted_at: :asc, id: :asc } : { id: :desc }
          records, meta = paginate(scope, order:)
          render_data(records.map { |p| ::Admin::WorkerSummaryResource.new(p).to_h }, meta:)
        end

        # GET /api/v1/admin/workers/:id
        def show
          authorize [ :admin, profile ]
          render_data(::Admin::WorkerDetailResource.new(profile).to_h)
        end

        # POST /api/v1/admin/workers/:id/verification { decision, reason, documents: [{ id, status, reason }] }
        def verify
          authorize [ :admin, profile ], :decide?
          ::Admin::DecideVerification.call(profile:, decision: params.require(:decision), reason: params[:reason],
                                           documents: params.fetch(:documents, []).map { |d| d.permit(:id, :status, :reason).to_h })
          render_data(::Admin::WorkerDetailResource.new(profile.reload).to_h)
        end

        # POST /api/v1/admin/workers/:id/suspend { reason }
        def suspend
          authorize [ :admin, profile ], :suspend?
          ::Admin::SuspendWorker.suspend(profile:, reason: params[:reason])
          render_data(::Admin::WorkerDetailResource.new(profile.reload).to_h)
        end

        # POST /api/v1/admin/workers/:id/reinstate { reason? }
        def reinstate
          authorize [ :admin, profile ], :reinstate?
          ::Admin::SuspendWorker.reinstate(profile:, reason: params[:reason])
          render_data(::Admin::WorkerDetailResource.new(profile.reload).to_h)
        end

        private

        def profile
          @profile ||= policy_scope([ :admin, WorkerProfile ]).find_by!(public_id: params[:id])
        end
      end
    end
  end
end
