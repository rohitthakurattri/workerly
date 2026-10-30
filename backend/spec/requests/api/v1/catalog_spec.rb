require "rails_helper"

RSpec.describe "Public catalog", type: :request do
  before do
    parent = create(:plumber)
    create(:service_category, slug: "geyser-repair", parent:, name_i18n: { "en" => "Geyser repair" })
    create(:service_category, slug: "hidden", active: false)
    create(:mohali)
    create(:city, slug: "zirakpur", launched: false)
  end

  it "lists active categories as a tree, in the requested language, cacheable" do
    get "/api/v1/categories", headers: json_headers("Accept-Language" => "hi")
    expect(json["data"].map { |c| c["slug"] }).to eq([ "plumber" ])
    expect(json.dig("data", 0, "children", 0, "slug")).to eq("geyser-repair")
    expect(response.headers["Cache-Control"]).to include("public")
  end

  it "shows one category" do
    get "/api/v1/categories/plumber", headers: json_headers
    expect(json.dig("data", "name")).to eq("Plumber")
    get "/api/v1/categories/hidden", headers: json_headers
    expect(response).to have_http_status(:not_found)
  end

  it "lists only launched cities" do
    get "/api/v1/cities", headers: json_headers
    expect(json["data"].map { |c| c["slug"] }).to eq([ "mohali" ])
    expect(json.dig("data", 0, "center")).to eq("lat" => 30.7046, "lng" => 76.7179)
  end
end
