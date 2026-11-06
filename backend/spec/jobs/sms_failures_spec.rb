require "rails_helper"

RSpec.describe "When SMS fails" do
  let(:user) { create(:user) }

  def failing(code)
    adapter = instance_double(Adapters::Sms::Fake)
    allow(adapter).to receive(:deliver).and_raise(Adapters::Sms::Error.new(code))
    allow(Adapters::Sms).to receive(:adapter).and_return(adapter)
  end

  it "keeps the in-app notification and doesn't fail the job" do
    failing(:rejected)
    n = Notifications::Deliver.call(user:, app: "worker", kind: "lead_new", title: "New job",
                                    sms: Adapters::Sms.message(:lead_new, category: "Plumber", locality: "Sector 70"))
    expect(n.reload.channels).to eq([ "in_app" ])
  end

  it "retries a login code only when another try could work" do
    failing(:rejected)
    expect { Identity::SendOtpSmsJob.perform_now("+919814000014", "123456") }.not_to raise_error

    failing(:timeout)
    expect { Identity::SendOtpSmsJob.perform_now("+919814000014", "123456") }.to have_enqueued_job(Identity::SendOtpSmsJob)
  end
end
