FactoryBot.define do
  factory :worker_profile do
    user { association :user, :worker }
    experience_years { 5 }
    bio { "Plumbing and bathroom fittings, 5 years in Mohali." }

    # Everything submit_for_review needs.
    trait :complete do
      after(:create) do |profile|
        profile.photo.attach(Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/photo.png"), "image/png"))
        profile.save!
        profile.worker_skills.create!(service_category: create(:plumber), experience_years: 5)
        profile.service_areas.create!(city: create(:mohali), center: GeoPoint.point(lat: 30.70, lng: 76.72), radius_m: 5000)
        create(:worker_document, worker_profile: profile, kind: "identity", doc_type: "pan", number_last4: "123F")
        create(:worker_document, worker_profile: profile, kind: "address", doc_type: "utility_bill")
      end
    end

    trait :pending_review do
      complete
      after(:create) { |p| p.update!(verification_status: "pending_review", submitted_at: Time.current) }
    end

    # An approved, available worker with one skill and one service area (defaults: plumber, 5 km
    # around Mohali Sector 70).
    trait :matchable do
      transient do
        lat { 30.70 }
        lng { 76.72 }
        radius_m { 5000 }
        category { nil }
      end
      after(:create) do |p, ev|
        p.photo.attach(Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/photo.png"), "image/png"))
        p.worker_skills.create!(service_category: ev.category || create(:plumber))
        p.service_areas.create!(city: create(:mohali), center: GeoPoint.point(lat: ev.lat, lng: ev.lng), radius_m: ev.radius_m)
        p.update!(verification_status: "approved", submitted_at: 2.days.ago, approved_at: 1.day.ago, available: true)
      end
    end

    trait :approved do
      complete
      after(:create) do |p|
        p.documents.update_all(status: "approved")
        p.update!(verification_status: "approved", submitted_at: 1.day.ago, approved_at: Time.current)
      end
    end
  end

  factory :worker_document do
    worker_profile
    kind { "identity" }
    doc_type { "pan" }
    file { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/id.jpg"), "image/jpeg") }
  end
end
