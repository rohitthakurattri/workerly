module Api
  module V1
    module Customer
      class ServiceRequestsController < BaseController
        FILTERS = { "active" => ServiceRequest::ACTIVE_STATUSES, "draft" => %w[draft],
                    "past" => %w[fulfilled expired cancelled] }.freeze

        # GET /api/v1/customer/service_requests?filter[status]=active|draft|past&cursor=…  (newest first)
        def index
          authorize ServiceRequest
          scope = policy_scope(ServiceRequest).includes(:service_category, :address, attachments: { file_attachment: :blob })
          filter = params.dig(:filter, :status)
          if filter.present?
            raise ApplicationError.new(:invalid_filter, status: :bad_request, details: { allowed: FILTERS.keys }) unless FILTERS.key?(filter)

            scope = scope.where(status: FILTERS[filter])
          end
          records, meta = paginate(scope, order: { id: :desc })
          render_data(records.map { |r| ServiceRequestSummaryResource.new(r).to_h }, meta:)
        end

        # GET /api/v1/customer/service_requests/:id
        def show
          service_request = find_request
          authorize service_request
          render_request(service_request)
        end

        # POST /api/v1/customer/service_requests { description?, address? } -> draft
        def create
          authorize ServiceRequest
          drafts = policy_scope(ServiceRequest).where(status: "draft").count
          raise ApplicationError.new(:too_many_drafts, details: { max: ServiceRequest::MAX_DRAFTS }) if drafts >= ServiceRequest::MAX_DRAFTS

          service_request = current_user.service_requests.new(urgency: "flexible")
          service_request.update!(request_attributes)
          render_request(service_request, status: :created)
        end

        # PATCH /api/v1/customer/service_requests/:id (draft only)
        # { description, category, address, answers: [{ question, answer }], urgency, preferred_from, preferred_to }
        def update
          service_request = find_request
          authorize service_request
          service_request.update!(request_attributes)
          render_request(service_request)
        end

        # DELETE /api/v1/customer/service_requests/:id — discard a draft.
        def destroy
          service_request = find_request
          authorize service_request
          service_request.attachments.each { |a| a.file.purge_later }
          service_request.destroy!
          head :no_content
        end

        # POST /api/v1/customer/service_requests/:id/submit
        def submit
          service_request = find_request
          authorize service_request
          Requests::Submit.call(request: service_request)
          render_request(service_request.reload)
        end

        # POST /api/v1/customer/service_requests/:id/cancel { reason? }
        def cancel
          service_request = find_request
          authorize service_request
          Requests::Cancel.call(request: service_request, reason: params[:reason])
          render_request(service_request)
        end

        private

        def request_attributes
          p = params.permit(:description, :category, :address, :urgency, :preferred_from, :preferred_to, answers: %i[question answer])
          attrs = p.slice(:description, :urgency, :preferred_from, :preferred_to).to_h
          attrs[:description] = attrs[:description].to_s.strip if attrs.key?(:description)
          attrs[:answers] = p[:answers].map { |a| { "question" => a[:question].to_s.strip, "answer" => a[:answer].to_s.strip } }.reject { |a| a["answer"].blank? } if p.key?(:answers)
          if p.key?(:category)
            attrs[:service_category] = p[:category].presence && ServiceCategory.requestable.find_by(slug: p[:category])
            raise ApplicationError.new(:unknown_categories, details: { categories: [ p[:category] ] }) if p[:category].present? && attrs[:service_category].nil?
          end
          attrs[:address] = p[:address].presence && policy_scope(Address).find_by!(public_id: p[:address]) if p.key?(:address)
          attrs
        end
      end
    end
  end
end
