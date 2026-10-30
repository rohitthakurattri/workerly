require "rails_helper"

RSpec.describe "Customer addresses", type: :request do
  let!(:mohali) { create(:mohali) }
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }
  let(:valid) { { label: "Home", line1: "House 1234", landmark: "Near gurdwara", locality: "Sector 70", pincode: "160 071", lat: 30.70, lng: 76.72 } }

  def create_address(**attrs) = post("/api/v1/customer/addresses", params: valid.merge(attrs).to_json, headers:)

  it "adds an address, derives the city from the pin and makes the first one the default" do
    create_address
    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("city" => "mohali", "pincode" => "160071", "is_default" => true,
                                    "location" => { "lat" => 30.7, "lng" => 76.72 })
  end

  it "refuses a pin outside every launched city" do
    create_address(lat: 28.61, lng: 77.21) # Delhi
    expect(json.dig("error", "details", "field_errors")).to have_key("location")
  end

  it "validates the PIN code and the required fields" do
    create_address(pincode: "012345", line1: "", locality: "")
    expect(json.dig("error", "details", "field_errors").keys).to include("pincode", "line1", "locality")
  end

  it "keeps exactly one default" do
    create_address
    first = json.dig("data", "id")
    create_address(label: "Office", is_default: true)
    get("/api/v1/customer/addresses", headers:)
    expect(json["data"].map { |a| [ a["label"], a["is_default"] ] }).to eq([ [ "Office", true ], [ "Home", false ] ])
    patch("/api/v1/customer/addresses/#{first}", params: { is_default: true }.to_json, headers:)
    expect(user.addresses.kept.where(is_default: true).pluck(:public_id)).to eq([ first ])
  end

  it "soft-deletes, so submitted requests keep their address" do
    request = create(:service_request, :open, customer: user)
    delete("/api/v1/customer/addresses/#{request.address.public_id}", headers:)
    expect(response).to have_http_status(:no_content)
    expect(request.address.reload.deleted_at).to be_present
    get("/api/v1/customer/addresses", headers:)
    expect(json["data"]).to be_empty
  end

  it "never shows or changes another customer's address" do
    other = create(:address)
    patch("/api/v1/customer/addresses/#{other.public_id}", params: { line1: "Mine now" }.to_json, headers:)
    expect(response).to have_http_status(:not_found)
    expect(other.reload.line1).not_to eq("Mine now")
  end

  it "allows at most 10 addresses" do
    create_list(:address, 10, user:)
    create_address
    expect(error_code).to eq("too_many_addresses")
  end

  it "needs the customer role" do
    profile = create(:worker_profile)
    get "/api/v1/customer/addresses", headers: auth_headers_for(profile.user, role: "worker")
    expect([ response.status, error_code ]).to eq([ 403, "role_required" ])
  end
end
