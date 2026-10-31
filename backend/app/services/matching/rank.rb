module Matching
  # Scores a candidate between 0 and 1. Defaults until the ranking question in the plan is
  # answered: closeness first, then rating, a fair share for workers who got few leads lately
  # (so new workers aren't starved), and how quickly they usually open leads.
  module Rank
    module_function

    WEIGHTS = { distance: 0.40, rating: 0.25, fairness: 0.20, responsiveness: 0.15 }.freeze
    # Bayesian average: a new worker counts as 5 reviews of 4.0 stars until real reviews arrive.
    PRIOR_RATING = 4.0
    PRIOR_COUNT = 5
    DISTANCE_HALF_KM = 3.0      # 3 km away scores half of 0 km
    FAIR_SHARE = 5.0            # leads per week before fairness halves
    MIN_HISTORY = 5             # invitations needed before responsiveness counts

    def score(c)
      parts = {
        distance: 1.0 / (1.0 + (c.distance_m / 1000.0) / DISTANCE_HALF_KM),
        rating: ((c.rating_avg.to_f * c.rating_count) + (PRIOR_RATING * PRIOR_COUNT)) / (c.rating_count + PRIOR_COUNT) / 5.0,
        fairness: 1.0 / (1.0 + (c.recent_invitations / FAIR_SHARE)),
        responsiveness: c.past_invitations < MIN_HISTORY ? 0.5 : c.quick_views.to_f / c.past_invitations
      }
      WEIGHTS.sum { |k, w| w * parts.fetch(k) }.round(4)
    end

    # Best first; ties go to the closer worker, then the earlier registration.
    def order(candidates)
      candidates.map { |c| [ c, score(c) ] }.sort_by { |c, s| [ -s, c.distance_m, c.worker_profile_id ] }
    end
  end
end
