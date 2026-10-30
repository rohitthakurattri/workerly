module Api
  module V1
    module Worker
      class DocumentsController < BaseController
        # GET /api/v1/worker/documents
        def index
          authorize current_profile, :show?
          render_data(current_profile.documents.order(:created_at).map { |d| WorkerDocumentResource.new(d).to_h })
        end

        # POST /api/v1/worker/documents (multipart: kind, doc_type, number_last4, file)
        def create
          authorize current_profile, :update_documents?
          doc = Workers::UploadDocument.call(profile: current_profile, kind: params.require(:kind),
                                             doc_type: params.require(:doc_type), number_last4: params[:number_last4],
                                             file: params.require(:file))
          render_data(WorkerDocumentResource.new(doc).to_h, status: :created)
        end

        # DELETE /api/v1/worker/documents/:id — only documents nobody has reviewed yet.
        def destroy
          authorize current_profile, :update_documents?
          doc = current_profile.documents.find_by!(public_id: params[:id])
          raise ApplicationError.new(:document_reviewed, status: :conflict) unless doc.status == "pending"

          doc.file.purge_later
          doc.destroy!
          head :no_content
        end
      end
    end
  end
end
