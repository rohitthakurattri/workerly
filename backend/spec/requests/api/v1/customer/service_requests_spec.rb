require "rails_helper"

RSpec.describe "Customer service requests", type: :request do
  let!(:mohali) { create(:mohali) }
  let!(:plumber) { create(:plumber) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }
  let(:address) { create(:address, user:) }

  def create_draft(**attrs)
    post("/api/v1/customer/service_requests", params: attrs.to_json, headers:)
    json.dig("data", "id")
  end

  def update_draft(id, **attrs) = patch("/api/v1/customer/service_requests/#{id}", params: attrs.to_json, headers:)

  it "creates a draft, completes it and submits it" do
    id = create_draft(description: "Bathroom tap leaking")
    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("status" => "draft", "missing" => %w[category address])

    update_draft(id, category: "plumber", address: address.public_id, urgency: "today",
                     answers: [ { question: "Where?", answer: "Bathroom" }, { question: "Since when?", answer: "" } ])
    expect(json["data"]).to include("missing" => [], "urgency" => "today", "answers" => [ { "question" => "Where?", "answer" => "Bathroom" } ])
    expect(json.dig("data", "category", "slug")).to eq("plumber")

    freeze_time do
      post("/api/v1/customer/service_requests/#{id}/submit", headers:)
      expect(json["data"]).to include("status" => "open", "submitted_at" => Time.current.iso8601,
                                      "expires_at" => 24.hours.from_now.iso8601, "cancellable" => true)
    end
    expect(json.dig("data", "address")).to include("locality" => "Sector 70", "city" => "mohali")
  end

  it "says what is missing instead of submitting an incomplete draft" do
    id = create_draft(description: "Help")
    post("/api/v1/customer/service_requests/#{id}/submit", headers:)
    expect(json["error"]).to include("code" => "request_incomplete", "details" => { "missing" => %w[description category address] })
  end

  it "keeps the address as it was at submit time" do
    request = create(:service_request, :open, customer: user)
    request.address.update!(line1: "Moved house", location: GeoPoint.point(lat: 30.73, lng: 76.78))
    get("/api/v1/customer/service_requests/#{request.public_id}", headers:)
    expect(json.dig("data", "address")).to include("line1" => "House 1234, Sector 70", "location" => { "lat" => 30.7, "lng" => 76.72 })
  end

  it "locks a submitted request against edits" do
    request = create(:service_request, :open, customer: user)
    update_draft(request.public_id, description: "Changed my mind about everything")
    expect([ response.status, error_code ]).to eq([ 403, "request_locked" ])
    post("/api/v1/customer/service_requests/#{request.public_id}/submit", headers:)
    expect(error_code).to eq("invalid_transition")
  end

  it "validates the time window" do
    id = create_draft
    update_draft(id, preferred_from: 2.days.from_now.iso8601, preferred_to: 1.day.from_now.iso8601)
    expect(json.dig("error", "details", "field_errors")).to have_key("preferred_to")
    update_draft(id, preferred_from: 2.days.ago.iso8601)
    expect(json.dig("error", "details", "field_errors")).to have_key("preferred_from")
    update_draft(id, urgency: "yesterday")
    expect(json.dig("error", "details", "field_errors")).to have_key("urgency")
  end

  it "refuses unknown categories and other customers' addresses" do
    id = create_draft
    update_draft(id, category: "astrology")
    expect(error_code).to eq("unknown_categories")
    update_draft(id, address: create(:address).public_id)
    expect(response).to have_http_status(:not_found)
  end

  it "cancels an open request but not a draft or a cancelled one" do
    request = create(:service_request, :open, customer: user)
    post("/api/v1/customer/service_requests/#{request.public_id}/cancel", params: { reason: "Fixed it myself" }.to_json, headers:)
    expect(json["data"]).to include("status" => "cancelled", "cancel_reason" => "Fixed it myself", "cancellable" => false)
    post("/api/v1/customer/service_requests/#{request.public_id}/cancel", headers:)
    expect([ response.status, error_code ]).to eq([ 403, "request_not_cancellable" ])
  end

  it "discards drafts only" do
    id = create_draft
    delete("/api/v1/customer/service_requests/#{id}", headers:)
    expect(response).to have_http_status(:no_content)
    open = create(:service_request, :open, customer: user)
    delete("/api/v1/customer/service_requests/#{open.public_id}", headers:)
    expect(error_code).to eq("request_locked")
  end

  it "lists the customer's own requests newest first, filtered by status" do
    drafts = create_list(:service_request, 2, customer: user)
    open = create(:service_request, :open, customer: user)
    create(:service_request, :open) # someone else's
    get("/api/v1/customer/service_requests", headers:)
    expect(json["data"].map { |r| r["id"] }).to eq([ open, *drafts.reverse ].map(&:public_id))
    get("/api/v1/customer/service_requests", params: { filter: { status: "active" } }, headers: headers.except("Content-Type"))
    expect(json["data"].map { |r| r["id"] }).to eq([ open.public_id ])
    expect(json["data"].first).to include("locality" => "Sector 70", "photo_count" => 0)
  end

  it "hides other customers' requests (404, not 403)" do
    other = create(:service_request, :open)
    get("/api/v1/customer/service_requests/#{other.public_id}", headers:)
    expect(response).to have_http_status(:not_found)
    post("/api/v1/customer/service_requests/#{other.public_id}/cancel", headers:)
    expect(response).to have_http_status(:not_found)
  end

  it "limits drafts and open requests" do
    create_list(:service_request, 5, customer: user)
    create_draft
    expect(error_code).to eq("too_many_drafts")

    ServiceRequest.where(customer: user).delete_all
    create_list(:service_request, 5, :open, customer: user)
    draft = create(:service_request, :ready, customer: user)
    post("/api/v1/customer/service_requests/#{draft.public_id}/submit", headers:)
    expect(error_code).to eq("too_many_active_requests")
  end

  it "requires the customer role" do
    profile = create(:worker_profile)
    get "/api/v1/customer/service_requests", headers: auth_headers_for(profile.user, role: "worker")
    expect([ response.status, error_code ]).to eq([ 403, "role_required" ])
  end

  it "enforces completeness in the database too" do
    request = create(:service_request)
    expect { request.update_columns(status: "open") }.to raise_error(ActiveRecord::StatementInvalid, /service_requests_submitted_complete_check/)
  end

  describe "photos" do
    let(:id) { create_draft }

    def upload(name, type = "image/jpeg")
      post("/api/v1/customer/service_requests/#{id}/attachments", params: { file: fixture(name, type) }, headers: multipart_headers(headers))
    end

    it "re-encodes photos as JPEG, applying rotation and removing EXIF and GPS" do
      upload("gps_photo.jpg")
      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("kind" => "image", "width" => 300, "height" => 400) # rotated upright
      expect(json.dig("data", "file", "expires_in")).to eq(300)

      blob = RequestAttachment.last.file.blob
      blob.open do |f|
        exif = MiniMagick::Image.new(f.path).exif
        expect(exif.keys.grep(/GPS/)).to be_empty
        expect(exif).not_to have_key("Make")
      end
    end

    it "shrinks large photos to at most 2048 px" do
      upload("large.png", "image/png")
      expect(json["data"]).to include("width" => 2048, "height" => 1365)
      expect(json.dig("data", "file", "content_type")).to eq("image/jpeg")
    end

    it "refuses files that are not images, whatever their name" do
      upload("renamed.jpg")
      expect(json.dig("error", "details", "field_errors")).to have_key("file")
      upload("address.pdf", "application/pdf")
      expect(json.dig("error", "details", "field_errors")).to have_key("file")
    end

    it "allows at most 6 photos, and removes them" do
      6.times { upload("id.jpg") }
      upload("id.jpg")
      expect(error_code).to eq("too_many_photos")

      photo = ServiceRequest.find_by!(public_id: id).attachments.first
      delete("/api/v1/customer/service_requests/#{id}/attachments/#{photo.public_id}", headers:)
      expect(response).to have_http_status(:no_content)
      get("/api/v1/customer/service_requests/#{id}", headers:)
      expect(json.dig("data", "photos").size).to eq(5)
    end

    it "can't add photos once the request is sent" do
      request = create(:service_request, :open, customer: user)
      post("/api/v1/customer/service_requests/#{request.public_id}/attachments", params: { file: fixture("id.jpg", "image/jpeg") },
                                                                                 headers: multipart_headers(headers))
      expect(error_code).to eq("request_locked")
    end
  end
end
