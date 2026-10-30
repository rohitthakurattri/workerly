module Api
  module V1
    module Customer
      class BaseController < Api::V1::BaseController
        before_action { require_role!(:customer) }

        private

        def find_request
          policy_scope(ServiceRequest).includes(:service_category, :triage_analysis, address: :city, attachments: { file_attachment: :blob })
                                      .find_by!(public_id: params[:service_request_id] || params[:id])
        end

        def render_request(request, status: :ok)
          render_data(ServiceRequestResource.new(request).to_h, status:)
        end
      end
    end
  end
end
