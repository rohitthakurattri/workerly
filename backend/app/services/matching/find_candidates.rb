module Matching
  # Workers who may receive a request: approved, not suspended, available, active account,
  # skilled in the category, and with a service area whose circle contains the request's
  # location. Never the customer themselves. Distance is to the nearest qualifying area centre.
  module FindCandidates
    module_function

    STATS_WINDOW = 30.days
    RECENT_WINDOW = 7.days
    QUICK_VIEW = 15.minutes

    Candidate = Data.define(:worker_profile_id, :distance_m, :rating_avg, :rating_count,
                            :recent_invitations, :past_invitations, :quick_views)

    SQL = <<~SQL.freeze
      SELECT wp.id AS worker_profile_id, area.distance_m, wp.rating_avg, wp.rating_count,
             COALESCE(stats.recent, 0) AS recent_invitations, COALESCE(stats.total, 0) AS past_invitations,
             COALESCE(stats.quick, 0) AS quick_views
      FROM worker_profiles wp
      JOIN users u ON u.id = wp.user_id
      JOIN worker_skills ws ON ws.worker_profile_id = wp.id AND ws.service_category_id = :category_id
      JOIN LATERAL (
        SELECT ST_Distance(a.center, :point::geography)::integer AS distance_m
        FROM worker_service_areas a
        WHERE a.worker_profile_id = wp.id
          AND ST_DWithin(a.center, :point::geography, :max_radius_m)  -- index-friendly bound
          AND ST_DWithin(a.center, :point::geography, a.radius_m)     -- the worker's own radius
        ORDER BY 1
        LIMIT 1
      ) area ON true
      LEFT JOIN LATERAL (
        SELECT count(*) FILTER (WHERE ri.created_at > :recent_since) AS recent,
               count(*) AS total,
               count(*) FILTER (WHERE ri.viewed_at <= ri.notified_at + :quick_view * interval '1 second') AS quick
        FROM request_invitations ri
        WHERE ri.worker_profile_id = wp.id AND ri.created_at > :stats_since
      ) stats ON true
      WHERE wp.verification_status = 'approved' AND wp.suspended_at IS NULL AND wp.available
        AND wp.deleted_at IS NULL AND u.status = 'active' AND u.deleted_at IS NULL
        AND wp.user_id <> :customer_id
    SQL

    def call(request, now: Time.current)
      sql = ApplicationRecord.sanitize_sql([ SQL, {
        category_id: request.service_category_id, point: request.location.as_text, customer_id: request.customer_id,
        max_radius_m: WorkerServiceArea::RADIUS_RANGE.max, recent_since: now - RECENT_WINDOW,
        stats_since: now - STATS_WINDOW, quick_view: QUICK_VIEW.to_i
      } ])
      ApplicationRecord.connection.select_all(sql).map do |row|
        Candidate.new(worker_profile_id: row["worker_profile_id"], distance_m: row["distance_m"].to_i,
                      rating_avg: row["rating_avg"]&.to_f, rating_count: row["rating_count"].to_i,
                      recent_invitations: row["recent_invitations"].to_i, past_invitations: row["past_invitations"].to_i,
                      quick_views: row["quick_views"].to_i)
      end
    end
  end
end
