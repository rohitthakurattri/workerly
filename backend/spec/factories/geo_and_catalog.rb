FactoryBot.define do
  factory :country do
    iso2 { "IN" }
    name { "India" }
    currency_code { "INR" }
    phone_prefix { "+91" }
    initialize_with { Country.find_or_initialize_by(iso2:) }
  end

  factory :state do
    country
    code { "PB" }
    name { "Punjab" }
    initialize_with { State.find_or_initialize_by(country_id: country.id, code:) }
  end

  factory :city do
    state
    sequence(:slug) { |n| "city-#{n}" }
    name_i18n { { "en" => slug.titleize } }
    currency_code { "INR" }
    time_zone { "Asia/Kolkata" }
    center { GeoPoint.point(lat: 30.7046, lng: 76.7179) }
    service_radius_m { 25_000 }
    launched { true }

    factory :mohali do
      slug { "mohali" }
      name_i18n { { "en" => "Mohali", "hi" => "मोहाली" } }
      initialize_with { City.find_or_initialize_by(slug:) }
    end
  end

  factory :service_category do
    sequence(:slug) { |n| "category-#{n}" }
    name_i18n { { "en" => slug.titleize } }

    factory :plumber do
      slug { "plumber" }
      name_i18n { { "en" => "Plumber", "hi" => "प्लंबर" } }
      initialize_with { ServiceCategory.find_or_initialize_by(slug:) }
    end
  end
end
