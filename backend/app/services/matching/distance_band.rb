module Matching
  # Workers see a band, never the exact distance, so the customer's home can't be triangulated.
  module DistanceBand
    BANDS = [ [ 1_000, "under_1km" ], [ 3_000, "1_3km" ], [ 5_000, "3_5km" ], [ 10_000, "5_10km" ] ].freeze

    def self.call(distance_m) = BANDS.find { |limit, _| distance_m < limit }&.last || "over_10km"
  end
end
