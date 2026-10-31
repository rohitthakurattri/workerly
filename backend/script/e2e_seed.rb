# Development-only fixtures for the Playwright smoke test. Prints JSON for the test runner.
abort "development only" unless Rails.env.development?

load Rails.root.join("db/seeds.rb")

phones = { dual: "+919814000001", admin: "+919814000099", logout: "+919814000002",
           fresh: "+9198140#{format("%05d", rand(100_000))}", new_worker: "+9198141#{format("%05d", rand(100_000))}",
           customer: "+9198142#{format("%05d", rand(100_000))}", pro_near: "+919814000011", pro_far: "+919814000012",
           pro_near2: "+919814000013" }
OtpChallenge.where(phone_e164: phones.values).delete_all

dual = User.kept.find_or_create_by!(phone_e164: phones[:dual])
%i[customer worker].each { |r| dual.grant_role!(r) }
dual.update!(name: "Dual Role") if dual.name.blank?
(dual.worker_profile || dual.create_worker_profile!).update!(verification_status: "approved", approved_at: Time.current,
                                                            submitted_at: Time.current, suspended_at: nil)

# Phase 4 matching: an approved, available plumber covering Mohali Sector 70, and one whose
# circle around Chandigarh Sector 17 stops short of it. Phase 5 adds a second Mohali plumber so
# a request gets two competing quotes.
plumber = ServiceCategory.find_by!(slug: "plumber")
{ pro_near: [ "Near Plumber", "mohali", 30.7010, 76.7210, 5000 ],
  pro_far: [ "Far Plumber", "chandigarh", 30.7398, 76.7827, 2000 ],
  pro_near2: [ "Second Plumber", "mohali", 30.7020, 76.7190, 5000 ] }.each do |key, (name, city, lat, lng, radius_m)|
  user = User.kept.find_or_create_by!(phone_e164: phones[key])
  %i[customer worker].each { |r| user.grant_role!(r) }
  user.update!(name:)
  profile = user.worker_profile || user.create_worker_profile!(experience_years: 5)
  profile.worker_skills.find_or_create_by!(service_category: plumber)
  profile.service_areas.destroy_all
  profile.service_areas.create!(city: City.find_by!(slug: city), center: GeoPoint.point(lat:, lng:), radius_m:)
  profile.update!(verification_status: "approved", submitted_at: Time.current, approved_at: Time.current,
                  suspended_at: nil, available: true)
end

admin = User.kept.find_or_create_by!(phone_e164: phones[:admin])
%i[customer admin support].each { |r| admin.grant_role!(r) }
Identity::Totp.provision!(admin)

# A phone-camera-sized photo (4000x3000, a few MB) for the Phase 3 request test, generated once.
camera_photo = Rails.root.join("tmp/e2e/camera.jpg")
unless camera_photo.exist?
  FileUtils.mkdir_p(camera_photo.dirname)
  system(MiniMagick.imagemagick7? ? "magick" : "convert", "-size", "4000x3000", "plasma:", "-quality", "92",
         camera_photo.to_s, exception: true)
end

puts({ phones:, totp_secret: admin.totp_secret, camera_photo: camera_photo.to_s }.to_json)
