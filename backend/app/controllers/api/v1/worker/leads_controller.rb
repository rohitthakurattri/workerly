module Api
  module V1
    module Worker
      class LeadsController < BaseController
        before_action { authorize :lead }

        # GET /api/v1/worker/leads — requests this worker was invited to that still take quotes, newest first.
        def index
          records, meta = paginate(leads, order: { id: :desc })
          quote_counts = Quotation.live.where(service_request_id: records.map(&:service_request_id)).group(:service_request_id).count
          render_data(records.map { |i| LeadResource.new(i, params: { quote_counts: }).to_h }, meta:)
        end

        # GET /api/v1/worker/leads/:id (the request's id). The first view is recorded (responsiveness ranking).
        def show
          invitation = find_lead
          invitation.update!(viewed_at: Time.current) unless invitation.viewed_at
          render_data(LeadResource.new(invitation).to_h)
        end

        # POST /api/v1/worker/leads/:id/decline { reason? } — hides the lead for this worker.
        def decline
          invitation = find_lead
          invitation.update!(declined_at: Time.current, decline_reason: params[:reason].to_s.strip.presence)
          head :no_content
        end

        private

        def leads
          current_profile.invitations.live
                         .includes(quotation: [ :booking, { revisions: :items } ],
                                   service_request: [ :service_category, :city, { attachments: { file_attachment: :blob } } ])
        end

        def find_lead
          leads.find_by!(service_requests: { public_id: params[:id] })
        end
      end
    end
  end
end
