require "rails_helper"

RSpec.describe Matching::NotifyWorkerJob, type: :job do
  let!(:mohali) { create(:mohali) }
  let(:worker) { create(:worker_profile, :matchable) }
  let(:request) { create(:service_request, :open) }
  let(:invitation) { request.invitations.create!(worker_profile: worker, rank: 1, rank_score: 0.8, distance_m: 450) }
  let(:vapid) { WebPush.generate_key }

  def subscribe(user = worker.user, endpoint: "https://fcm.googleapis.com/fcm/send/abc")
    user.device_subscriptions.create!(app: "worker", endpoint:, p256dh: Base64.urlsafe_encode64(OpenSSL::PKey::EC.generate("prime256v1").public_key.to_bn.to_s(2)), auth: Base64.urlsafe_encode64(Random.bytes(16)))
  end

  before { with_config(vapid_public_key: vapid.public_key, vapid_private_key: vapid.private_key) }

  it "shows the lead live in the worker app" do
    expect { described_class.perform_now(invitation.id) }
      .to have_broadcasted_to(worker).from_channel(WorkerLeadsChannel).with(hash_including(type: "lead.new"))
  end

  it "sends web push and no SMS when a device accepts it" do
    subscribe
    stub = stub_request(:post, "https://fcm.googleapis.com/fcm/send/abc").to_return(status: 201)
    described_class.perform_now(invitation.id)
    expect(stub).to have_been_requested
    expect(Adapters::Sms::Fake.deliveries).to be_empty
    expect(invitation.reload).to have_attributes(notified_via: "push", notified_at: be_present)
    expect(worker.user.notifications.last).to have_attributes(kind: "lead.new", title: "New job: Plumber", channels: %w[in_app push],
                                                              url: "/leads/#{request.public_id}")
  end

  it "falls back to SMS when the worker has no push subscription" do
    described_class.perform_now(invitation.id)
    expect(Adapters::Sms::Fake.deliveries.last.body).to include("Plumber in Sector 70")
    expect(invitation.reload.notified_via).to eq("sms")
  end

  it "drops expired subscriptions and falls back to SMS" do
    subscribe
    stub_request(:post, "https://fcm.googleapis.com/fcm/send/abc").to_return(status: 410)
    described_class.perform_now(invitation.id)
    expect(worker.user.device_subscriptions.reload).to be_empty
    expect(invitation.reload.notified_via).to eq("sms")
  end

  it "uses SMS when push is not configured" do
    with_config(vapid_public_key: nil, vapid_private_key: nil)
    subscribe
    described_class.perform_now(invitation.id)
    expect(invitation.reload.notified_via).to eq("sms")
  end

  it "stays quiet when SMS fallback is off and there's no push" do
    with_config(lead_sms_fallback: false)
    described_class.perform_now(invitation.id)
    expect(Adapters::Sms::Fake.deliveries).to be_empty
    expect(invitation.reload.notified_via).to eq("none")
  end

  it "doesn't notify about requests that closed, or workers who can no longer take leads" do
    Requests::Cancel.call(request:)
    described_class.perform_now(invitation.id)
    expect(Adapters::Sms::Fake.deliveries).to be_empty
    expect(invitation.reload.notified_via).to eq("none")
  end

  it "notifies once even if the job runs twice" do
    2.times { described_class.perform_now(invitation.id) }
    expect(Adapters::Sms::Fake.deliveries.size).to eq(1)
  end

  it "writes in the worker's language" do
    worker.user.update!(locale: "hi")
    described_class.perform_now(invitation.id)
    expect(worker.user.notifications.last.title).to eq("नया काम: प्लंबर")
  end
end
