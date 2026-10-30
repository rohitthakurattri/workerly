FactoryBot.define do
  factory :address do
    user
    city { association :mohali }
    line1 { "House 1234, Sector 70" }
    locality { "Sector 70" }
    pincode { "160071" }
    location { GeoPoint.point(lat: 30.7000, lng: 76.7200) }
  end

  factory :service_request do
    customer { association :user }
    description { "Kitchen tap is leaking and the pipe under the sink drips." }

    # Everything Requests::Submit needs.
    trait :ready do
      service_category { association :plumber }
      address { association :address, user: customer }
    end

    trait :open do
      ready
      after(:create) { |r| Requests::Submit.call(request: r) }
    end
  end
end
