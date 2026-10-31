module Api
  module V1
    module Admin
      class ServiceRequestsController < BaseController
        STATUSES = ServiceRequest::STATUSES - %w[draft]
        WAITING_AFTER = 30.minutes

        # GET /api/v1/admin/service_requests?filter[status]=open&filter[attention]=true&cursor=…
        # attention: open with nobody invited, or open for 30+ minutes (open = no quotes yet; the first quote moves it to quoting).
        def index
          authorize [ :admin, ServiceRequest ]
          scope = policy_scope([ :admin, ServiceRequest ]).includes(:service_category, :city, :customer)
          status = params.dig(:filter, :status)
          if status.present?
            raise ApplicationError.new(:invalid_filter, status: :bad_request, details: { allowed: STATUSES }) unless STATUSES.include?(status)

            scope = scope.where(status:)
          end
          scope = needing_attention(scope) if params.dig(:filter, :attention) == "true"
          records, meta = paginate(scope, order: { id: :desc })
          render_data(records.map { |r| ::Admin::ServiceRequestSummaryResource.new(r).to_h },
                      meta: meta.merge(attention_count: needing_attention(policy_scope([ :admin, ServiceRequest ])).count))
        end

        # GET /api/v1/admin/service_requests/:id
        def show
          record = policy_scope([ :admin, ServiceRequest ]).find_by!(public_id: params[:id])
          authorize [ :admin, record ]
          render_data(::Admin::ServiceRequestDetailResource.new(record).to_h)
        end

        private

        def needing_attention(scope)
          scope.where(status: "open").where("service_requests.invited_count = 0 OR service_requests.submitted_at < ?", WAITING_AFTER.ago)
        end
      end
    end
  end
end
