module Api
  module V1
    module Customer
      class AttachmentsController < BaseController
        # POST /api/v1/customer/service_requests/:service_request_id/attachments (multipart: file)
        def create
          service_request = find_request
          authorize service_request, :update?
          attachment = Requests::AddPhoto.call(request: service_request, file: params.require(:file))
          render_data(RequestAttachmentResource.new(attachment).to_h, status: :created)
        end

        # DELETE /api/v1/customer/service_requests/:service_request_id/attachments/:id
        def destroy
          service_request = find_request
          authorize service_request, :update?
          attachment = service_request.attachments.find_by!(public_id: params[:id])
          attachment.file.purge_later
          attachment.destroy!
          head :no_content
        end
      end
    end
  end
end
