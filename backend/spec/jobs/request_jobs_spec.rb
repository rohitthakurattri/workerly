require "rails_helper"

RSpec.describe "Request jobs", type: :job do
  let!(:mohali) { create(:mohali) }

  describe Requests::ExpireJob do
    it "expires open requests past expires_at and closes their leads" do
      worker = create(:worker_profile, :matchable)
      due = create(:service_request, :open)
      due.invitations.create!(worker_profile: worker, rank: 1, rank_score: 0.5, distance_m: 10)
      fresh = create(:service_request, :open)

      travel(25.hours) do
        expect { described_class.perform_now }
          .to have_broadcasted_to(worker).from_channel(WorkerLeadsChannel).with(type: "lead.closed", id: due.public_id, status: "expired")
      end
      expect(due.reload.status).to eq("expired")
      expect(fresh.reload.status).to eq("expired") # also 24 h old by then

      later = create(:service_request, :open)
      described_class.perform_now
      expect(later.reload.status).to eq("open")
    end

    it "is scheduled every 5 minutes" do
      schedule = YAML.safe_load_file(Rails.root.join("config/schedule.yml"))
      expect(schedule["expire_requests"]).to include("cron" => "*/5 * * * *", "class" => "Requests::ExpireJob")
    end
  end

  describe Requests::PurgeStaleDraftsJob do
    it "deletes drafts untouched for 30 days, with their photos and AI log" do
      old = create(:service_request, description: "Kitchen tap leaking badly")
      Requests::AddPhoto.call(request: old, file: fixture("id.jpg", "image/jpeg"))
      Ai::TriageRequest.call(request: old, user: old.customer)
      recent = create(:service_request)
      old.update_columns(updated_at: 31.days.ago)

      expect { described_class.perform_now }.to change(ServiceRequest, :count).by(-1)
      expect(ServiceRequest.exists?(recent.id)).to be(true)
      expect(AiAnalysis.where(analysable_id: old.id)).to be_empty
    end

    it "never touches submitted requests" do
      sent = create(:service_request, :open)
      sent.update_columns(updated_at: 90.days.ago)
      described_class.perform_now
      expect(ServiceRequest.exists?(sent.id)).to be(true)
    end
  end
end
