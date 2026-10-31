require "rails_helper"

RSpec.describe BookingChannel, type: :channel do
  let!(:mohali) { create(:mohali) }
  let(:booking) { booked! }

  it "streams the booking to its customer and its worker" do
    stub_connection(current_user: booking.customer, current_role: "customer")
    subscribe(id: booking.public_id)
    expect(subscription).to have_stream_for(booking)

    stub_connection(current_user: booking.worker_profile.user, current_role: "worker")
    subscribe(id: booking.public_id)
    expect(subscription).to have_stream_for(booking)
  end

  it "rejects anyone else, or the right person in the wrong role" do
    stub_connection(current_user: create(:user), current_role: "customer")
    subscribe(id: booking.public_id)
    expect(subscription).to be_rejected

    stub_connection(current_user: booking.customer, current_role: "worker")
    subscribe(id: booking.public_id)
    expect(subscription).to be_rejected
  end
end
