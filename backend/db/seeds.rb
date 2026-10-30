# Reference data. Idempotent: safe to run on every deploy (bin/rails db:seed).
# Hindi/Punjabi names need native-speaker review before launch.

india = Country.find_or_initialize_by(iso2: "IN")
india.update!(name: "India", currency_code: "INR", phone_prefix: "+91")

states = {
  "PB" => [ "Punjab", "state" ],
  "CH" => [ "Chandigarh", "union_territory" ],
  "HR" => [ "Haryana", "state" ]
}.to_h do |code, (name, kind)|
  state = india.states.find_or_initialize_by(code:)
  state.update!(name:, kind:)
  [ code, state ]
end

cities = [
  # slug, state, en, hi, pa, lat, lng, launched
  [ "mohali", "PB", "Mohali", "मोहाली", "ਮੋਹਾਲੀ", 30.7046, 76.7179, true ],
  [ "chandigarh", "CH", "Chandigarh", "चंडीगढ़", "ਚੰਡੀਗੜ੍ਹ", 30.7333, 76.7794, true ],
  [ "zirakpur", "PB", "Zirakpur", "ज़ीरकपुर", "ਜ਼ੀਰਕਪੁਰ", 30.6425, 76.8173, false ],
  [ "panchkula", "HR", "Panchkula", "पंचकूला", "ਪੰਚਕੂਲਾ", 30.6942, 76.8606, false ]
]
cities.each do |slug, state, en, hi, pa, lat, lng, launched|
  city = City.find_or_initialize_by(slug:)
  attrs = { state: states.fetch(state), name_i18n: { en:, hi:, pa: }, currency_code: "INR",
            time_zone: "Asia/Kolkata", center: GeoPoint.point(lat:, lng:), service_radius_m: 25_000 }
  # Never un-launch a city from seeds; launching is an admin decision after the first seed.
  attrs[:launched] = launched if city.new_record?
  city.update!(attrs)
end

categories = [
  # slug, icon, en, hi, pa, inspection_allowed
  [ "plumber", "wrench", "Plumber", "प्लंबर", "ਪਲੰਬਰ", true ],
  [ "electrician", "zap", "Electrician", "इलेक्ट्रीशियन", "ਇਲੈਕਟ੍ਰੀਸ਼ੀਅਨ", true ],
  [ "carpenter", "hammer", "Carpenter", "बढ़ई", "ਤਰਖਾਣ", true ],
  [ "ac-repair", "snowflake", "AC repair & service", "एसी रिपेयर और सर्विस", "ਏਸੀ ਮੁਰੰਮਤ ਅਤੇ ਸਰਵਿਸ", true ],
  [ "painter", "paint-roller", "Painter", "पेंटर", "ਪੇਂਟਰ", true ],
  [ "appliance-repair", "washing-machine", "Appliance repair", "उपकरण मरम्मत", "ਉਪਕਰਣ ਮੁਰੰਮਤ", true ]
]
categories.each_with_index do |(slug, icon, en, hi, pa, inspection), i|
  c = ServiceCategory.find_or_initialize_by(slug:)
  c.update!(icon:, name_i18n: { en:, hi:, pa: }, inspection_allowed: inspection, sort: i * 10)
end

puts "Seeded #{Country.count} country, #{State.count} states, #{City.count} cities (#{City.launched.count} launched), #{ServiceCategory.count} categories."
