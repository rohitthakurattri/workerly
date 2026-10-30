require "rails_helper"

RSpec.describe "Worker onboarding", type: :request do
  let!(:mohali) { create(:mohali) }
  let!(:plumber) { create(:plumber) }

  describe "POST /api/v1/worker/registration" do
    let(:user) { create(:user, name: nil) }
    let(:headers) { auth_headers_for(user) }

    it "grants the worker role, creates a draft profile and returns a worker access token" do
      post "/api/v1/worker/registration", params: { name: "Harpreet Singh" }.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(user.reload.roles).to contain_exactly("customer", "worker")
      expect(json.dig("data", "profile", "verification_status")).to eq("draft")
      expect(json.dig("data", "profile", "missing")).to include("photo", "skills", "service_area", "document_identity", "document_address")

      get "/api/v1/worker/profile", headers: json_headers("Authorization" => "Bearer #{json.dig('data', 'access_token')}")
      expect(response).to have_http_status(:ok)
    end

    it "requires a name" do
      post "/api/v1/worker/registration", params: {}.to_json, headers: headers
      expect(error_code).to eq("name_required")
    end

    it "cannot register twice" do
      create(:worker_profile, user: create(:user, :worker, phone_e164: "+919811111111"))
      registered = User.find_by(phone_e164: "+919811111111")
      post "/api/v1/worker/registration", params: { name: "X" }.to_json, headers: auth_headers_for(registered)
      expect(error_code).to eq("already_registered")
    end

    it "is not available to staff sessions" do
      admin = create(:user, :admin, name: "A")
      post "/api/v1/worker/registration", params: {}.to_json, headers: staff_headers_for(admin, role: "admin")
      expect(error_code).to eq("consumer_session_required")
    end
  end

  context "with a draft profile" do
    let(:profile) { create(:worker_profile, experience_years: nil) }
    let(:headers) { auth_headers_for(profile.user, role: "worker") }

    it "updates bio, experience and photo (multipart)" do
      patch "/api/v1/worker/profile", headers: multipart_headers(headers),
                                      params: { profile: { bio: "Taps, pipes, geysers", experience_years: 7, photo: fixture("photo.png", "image/png") } }
      expect(response).to have_http_status(:ok)
      expect(json["data"]).to include("bio" => "Taps, pipes, geysers", "experience_years" => 7)
      expect(json.dig("data", "photo", "url")).to be_present
      expect(json.dig("data", "photo", "expires_in")).to eq(300)
    end

    it "rejects a photo that is not an image" do
      patch "/api/v1/worker/profile", headers: multipart_headers(headers),
                                      params: { profile: { photo: fixture("address.pdf", "application/pdf") } }
      expect(json.dig("error", "details", "field_errors")).to have_key("photo")
    end

    it "replaces the skill set" do
      electrician = create(:service_category, slug: "electrician")
      put "/api/v1/worker/skills", params: { skills: [ { category: "plumber", experience_years: 4 }, { category: "electrician" } ] }.to_json, headers: headers
      expect(json.dig("data", "skills").map { |s| s["category"] }).to contain_exactly("plumber", "electrician")

      put "/api/v1/worker/skills", params: { skills: [ { category: "electrician", experience_years: 2 } ] }.to_json, headers: headers
      expect(profile.worker_skills.reload.map(&:service_category)).to eq([ electrician ])
    end

    it "rejects unknown or inactive categories" do
      create(:service_category, slug: "retired", active: false)
      put "/api/v1/worker/skills", params: { skills: [ { category: "retired" }, { category: "astrology" } ] }.to_json, headers: headers
      expect(json["error"]).to include("code" => "unknown_categories", "details" => { "categories" => %w[retired astrology] })
    end

    describe "service areas" do
      def create_area(**attrs)
        post "/api/v1/worker/service_areas", headers:,
                                             params: { city: "mohali", lat: 30.70, lng: 76.72, radius_m: 5000 }.merge(attrs).to_json
      end

      it "adds an area inside a launched city" do
        create_area(label: "Phase 7")
        expect(response).to have_http_status(:created)
        expect(json["data"]).to include("city" => "mohali", "radius_m" => 5000, "label" => "Phase 7",
                                        "center" => { "lat" => 30.7, "lng" => 76.72 })
      end

      it "refuses points far from the city" do
        create_area(lat: 28.61, lng: 77.21) # Delhi
        expect(json.dig("error", "details", "field_errors")).to have_key("center")
      end

      it "refuses cities that have not launched" do
        create(:city, slug: "zirakpur", launched: false, center: GeoPoint.point(lat: 30.64, lng: 76.82))
        create_area(city: "zirakpur", lat: 30.64, lng: 76.82)
        expect(json.dig("error", "details", "field_errors")).to have_key("city")
      end

      it "keeps the radius between 500 m and 50 km" do
        create_area(radius_m: 100)
        expect(json.dig("error", "details", "field_errors")).to have_key("radius_m")
      end

      it "allows at most 3 areas" do
        3.times { create_area }
        create_area
        expect(error_code).to eq("too_many_service_areas")
      end

      it "updates and deletes only the worker's own areas" do
        create_area
        id = json.dig("data", "id")
        patch "/api/v1/worker/service_areas/#{id}", params: { radius_m: 8000 }.to_json, headers: headers
        expect(json.dig("data", "radius_m")).to eq(8000)

        other = create(:worker_profile, :complete)
        delete "/api/v1/worker/service_areas/#{other.service_areas.first.public_id}", headers: headers
        expect(response).to have_http_status(:not_found)

        delete "/api/v1/worker/service_areas/#{id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end
    end

    describe "documents" do
      def upload(kind: "identity", doc_type: "pan", file: fixture("id.jpg", "image/jpeg"), number_last4: "ABCD1234F")
        post "/api/v1/worker/documents", headers: multipart_headers(headers), params: { kind:, doc_type:, file:, number_last4: }
      end

      it "stores a document with only the last 4 characters of its number" do
        upload
        expect(response).to have_http_status(:created)
        expect(json["data"]).to include("kind" => "identity", "doc_type" => "pan", "number_last4" => "234F", "status" => "pending")
        expect(WorkerDocument.last.attributes.values.join).not_to include("ABCD1234F")
      end

      it "accepts PDFs" do
        upload(kind: "address", doc_type: "utility_bill", file: fixture("address.pdf", "application/pdf"))
        expect(json.dig("data", "file", "content_type")).to eq("application/pdf")
      end

      it "sniffs the real file type instead of trusting the name" do
        upload(file: fixture("renamed.jpg", "image/jpeg"))
        expect(json.dig("error", "details", "field_errors")).to have_key("file")
      end

      it "rejects doc types that don't prove that kind" do
        upload(kind: "address", doc_type: "pan")
        expect(json.dig("error", "details", "field_errors")).to have_key("doc_type")
      end

      it "replaces an unreviewed document of the same kind" do
        upload(doc_type: "pan")
        upload(doc_type: "voter_id")
        expect(profile.documents.reload.map(&:doc_type)).to eq([ "voter_id" ])
      end

      it "rejects files over 10 MB" do
        big = Tempfile.new([ "big", ".pdf" ])
        big.binmode
        big.write(File.binread(Rails.root.join("spec/fixtures/files/address.pdf")))
        big.write("0" * 10.megabytes)
        big.rewind
        upload(file: Rack::Test::UploadedFile.new(big.path, "application/pdf"))
        expect(json.dig("error", "details", "field_errors", "file").join).to include("10 MB")
      end

      it "cannot see another worker's documents" do
        other = create(:worker_profile, :complete)
        delete "/api/v1/worker/documents/#{other.documents.first.public_id}", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "submit for review" do
      it "lists what is missing" do
        post "/api/v1/worker/profile/submit_for_review", headers: headers
        expect(error_code).to eq("profile_incomplete")
        expect(json.dig("error", "details", "missing")).to include("photo", "experience_years", "skills", "service_area", "document_identity", "document_address")
      end

      it "moves a complete profile to pending_review and then locks documents" do
        complete = create(:worker_profile, :complete)
        h = auth_headers_for(complete.user, role: "worker")
        post "/api/v1/worker/profile/submit_for_review", headers: h
        expect(json.dig("data", "verification_status")).to eq("pending_review")
        expect(json.dig("data", "missing")).to eq([])

        post "/api/v1/worker/documents", headers: multipart_headers(h), params: { kind: "trade", doc_type: "trade_certificate", file: fixture("id.jpg", "image/jpeg") }
        expect(error_code).to eq("profile_locked")

        post "/api/v1/worker/profile/submit_for_review", headers: h
        expect(error_code).to eq("profile_locked")
      end
    end

    it "shows verification status" do
      get "/api/v1/worker/verification", headers: headers
      expect(json["data"].keys).to contain_exactly("verification_status", "editable", "suspended", "missing", "documents", "last_decision", "submitted_at", "approved_at")
    end
  end

  it "requires the worker role for worker endpoints" do
    get "/api/v1/worker/profile", headers: auth_headers_for(create(:user))
    expect(error_code).to eq("role_required")
  end
end
