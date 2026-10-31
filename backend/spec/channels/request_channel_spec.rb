require "rails_helper"

RSpec.describe RequestChannel, type: :channel do
  let!(:mohali) { create(:mohali) }
  let(:customer) { create(:user) }
  let(:service_request) { create(:service_request, :open, customer:) }

  it "streams the customer's own submitted request" do
    stub_connection(current_user: customer, current_role: "customer")
    subscribe(id: service_request.public_id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(service_request)
  end

  it "rejects other customers, drafts and the worker role" do
    stub_connection(current_user: create(:user), current_role: "customer")
    subscribe(id: service_request.public_id)
    expect(subscription).to be_rejected

    stub_connection(current_user: customer, current_role: "customer")
    subscribe(id: create(:service_request, customer:).public_id)
    expect(subscription).to be_rejected

    stub_connection(current_user: customer, current_role: "worker")
    subscribe(id: service_request.public_id)
    expect(subscription).to be_rejected
  end
end
