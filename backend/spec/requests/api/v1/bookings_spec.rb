require "rails_helper"

RSpec.describe "Bookings API", type: :request do
  let!(:mohali) { create(:mohali) }
  let(:booking) { booked! }
  let(:customer) { auth_headers_for(booking.customer) }
  let(:worker) { auth_headers_for(booking.worker_profile.user, role: "worker") }

  def finish!(b)
    act!(b, :schedule, params: { scheduled_at: soon })
    act!(b, :start)
    act!(b, :complete)
    b.reload
  end

  it "shows each side only the buttons they can press, and both sides the same status" do
    get("/api/v1/worker/bookings/#{booking.public_id}", headers: worker)
    expect(json["data"]).to include("status" => "confirmed", "actions" => %w[schedule cancel], "contact_visible" => true, "chat_open" => true)
    get("/api/v1/customer/bookings/#{booking.public_id}", headers: customer)
    expect(json["data"]).to include("status" => "confirmed", "actions" => %w[cancel], "can_review" => false, "can_dispute" => false)
    expect(json.dig("data", "history").map { |h| h["to"] }).to eq(%w[confirmed])
  end

  it "notifies the other side and refreshes both screens" do
    expect do
      perform_enqueued_jobs(only: Bookings::NotifyJob) do
        post("/api/v1/worker/bookings/#{booking.public_id}/schedule", params: { scheduled_at: soon }.to_json, headers: worker)
      end
    end.to have_broadcasted_to(BookingChannel.broadcasting_for(booking)).with(hash_including(type: "booking.updated", status: "scheduled"))
    expect(booking.customer.notifications.last).to have_attributes(kind: "booking.schedule", url: "/bookings/#{booking.public_id}")
    expect(booking.customer.notifications.last.title).to start_with(booking.worker_profile.user.name)
  end

  it "chats both ways, live, and closes the chat 48 h after completion" do
    post("/api/v1/customer/bookings/#{booking.public_id}/messages", params: { body: "Gate code is 1234" }.to_json, headers: customer)
    expect(response).to have_http_status(:created)
    expect do
      post("/api/v1/worker/bookings/#{booking.public_id}/messages", params: { body: "Thanks, on my way" }.to_json, headers: worker)
    end.to have_broadcasted_to(BookingChannel.broadcasting_for(booking)).with(hash_including(type: "message.new"))
    get("/api/v1/customer/bookings/#{booking.public_id}/messages", headers: customer)
    expect(json["data"].map { |m| [ m["sender_role"], m["body"] ] }).to eq([ %w[customer Gate\ code\ is\ 1234], [ "worker", "Thanks, on my way" ] ])

    get("/api/v1/customer/bookings/#{booking.public_id}/messages", headers: auth_headers_for(create(:user)))
    expect(response).to have_http_status(:not_found)
    post("/api/v1/customer/bookings/#{booking.public_id}/messages", params: { body: "" }.to_json, headers: customer)
    expect(response).to have_http_status(:bad_request)

    finish!(booking)
    travel(49.hours) do
      post("/api/v1/customer/bookings/#{booking.public_id}/messages", params: { body: "hello?" }.to_json, headers: auth_headers_for(booking.customer))
      expect(error_code).to eq("chat_closed")
      get("/api/v1/worker/bookings/#{booking.public_id}", headers: auth_headers_for(booking.worker_profile.user, role: "worker"))
      expect(json["data"]).to include("customer" => nil, "address" => nil, "contact_visible" => false)
    end
  end

  it "takes one review after completion and shows it to the worker" do
    post("/api/v1/customer/bookings/#{booking.public_id}/review", params: { rating: 5 }.to_json, headers: customer)
    expect(error_code).to eq("review_not_allowed")
    finish!(booking)
    post("/api/v1/customer/bookings/#{booking.public_id}/review", params: { rating: 5, body: "Quick and tidy" }.to_json, headers: customer)
    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("can_review" => false)
    expect(json.dig("data", "review", "rating")).to eq(5)
    post("/api/v1/customer/bookings/#{booking.public_id}/review", params: { rating: 1 }.to_json, headers: customer)
    expect(error_code).to eq("already_reviewed")

    get("/api/v1/worker/reviews", headers: worker)
    expect(json["data"].sole).to include("rating" => 5, "body" => "Quick and tidy")
    expect(json["meta"]).to include("rating_avg" => 5.0, "rating_count" => 1)
  end

  it "rejects out-of-range ratings" do
    finish!(booking)
    post("/api/v1/customer/bookings/#{booking.public_id}/review", params: { rating: 9 }.to_json, headers: customer)
    expect(response).to have_http_status(:unprocessable_content)
  end

  describe "disputes and support" do
    let(:support) { staff_headers_for(create(:user, :support), role: "support") }

    it "lets the customer report a problem and support resolve it, audited" do
      finish!(booking)
      post("/api/v1/customer/bookings/#{booking.public_id}/disputes", params: { category: "quality", description: "Still dripping" }.to_json, headers: customer)
      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("status" => "disputed", "can_dispute" => false)
      expect(json.dig("data", "dispute")).to include("status" => "open", "category" => "quality")

      get("/api/v1/admin/disputes", headers: support)
      dispute = json["data"].sole
      expect(dispute).to include("booking_id" => booking.public_id, "description" => "Still dripping")
      get("/api/v1/admin/bookings?filter[attention]=true", headers: support)
      expect(json["data"].map { |b| b["id"] }).to include(booking.public_id)

      post("/api/v1/admin/disputes/#{dispute['id']}/resolve", params: { resolution: "" }.to_json, headers: support)
      expect(error_code).to eq("reason_required")
      post("/api/v1/admin/disputes/#{dispute['id']}/resolve", params: { resolution: "Worker revisited" }.to_json, headers: support)
      expect(json["data"]).to include("status" => "resolved", "booking_status" => "completed")
      expect(AdminAction.last).to have_attributes(action: "dispute.resolved", reason: "Worker revisited")
    end

    it "shows support the whole booking and lets them cancel it with a reason" do
      post("/api/v1/customer/bookings/#{booking.public_id}/messages", params: { body: "Hi" }.to_json, headers: customer)
      get("/api/v1/admin/bookings/#{booking.public_id}", headers: support)
      expect(json["data"]).to include("actions" => [ "admin_cancel" ])
      expect(json.dig("data", "messages").sole["body"]).to eq("Hi")
      expect(json.dig("data", "customer", "phone")).to eq(booking.customer.phone_e164)

      post("/api/v1/admin/bookings/#{booking.public_id}/cancel", params: { reason: "" }.to_json, headers: support)
      expect(error_code).to eq("reason_required")
      post("/api/v1/admin/bookings/#{booking.public_id}/cancel", params: { reason: "Worker unreachable" }.to_json, headers: support)
      expect(json["data"]).to include("status" => "cancelled", "cancelled_by" => "admin")
      expect(AdminAction.last).to have_attributes(action: "booking.cancelled")

      get("/api/v1/admin/bookings", headers: auth_headers_for(create(:user)))
      expect(response).to have_http_status(:forbidden)
    end

    it "flags bookings nobody scheduled within a day" do
      booking.update_columns(confirmed_at: 25.hours.ago)
      get("/api/v1/admin/bookings?filter[attention]=true", headers: support)
      expect(json["meta"]["attention_count"]).to eq(1)
    end
  end
end
