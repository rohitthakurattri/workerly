module Ai
  # How good triage is on real traffic: the AI's suggestion against the category the customer
  # finally submitted (they always confirm it, so the submitted category is the label).
  # Requests the AI never saw (flag off, provider down, customer skipped it) count as not triaged.
  module TriageAccuracy
    module_function

    BUCKETS = [ [ 0.0, 0.4 ], [ 0.4, 0.6 ], [ 0.6, 0.8 ], [ 0.8, 1.0 ] ].freeze

    def call(from:, to:)
      submitted = ServiceRequest.where(submitted_at: from..to).where.not(service_category_id: nil)
      rows = submitted.joins(:triage_analysis).merge(AiAnalysis.succeeded)
                      .pluck(:service_category_id, "ai_analyses.suggested_category_id", "ai_analyses.confidence",
                             "ai_analyses.prompt_version", "ai_analyses.model")
                      .map { |final, suggested, conf, version, model| { final:, suggested:, confidence: conf.to_f, version:, model: } }
      slugs = ServiceCategory.pluck(:id, :slug).to_h
      preselected = rows.select { |r| r[:suggested] && r[:confidence] >= TriageRequest::LOW_CONFIDENCE }

      {
        from: from.iso8601, to: to.iso8601,
        submitted: submitted.count, triaged: rows.size, coverage: ratio(rows.size, submitted.count),
        accuracy: accuracy(rows),
        preselected: { count: preselected.size, share: ratio(preselected.size, rows.size), accuracy: accuracy(preselected) },
        no_suggestion: rows.count { |r| r[:suggested].nil? },
        calibration: BUCKETS.map do |lo, hi|
          bucket = rows.select { |r| r[:suggested] && r[:confidence] >= lo && (r[:confidence] < hi || (hi == 1.0 && r[:confidence] <= hi)) }
          { from: lo, to: hi, count: bucket.size, accuracy: accuracy(bucket) }
        end,
        categories: slugs.filter_map do |id, slug|
          actual = rows.count { |r| r[:final] == id }
          predicted = rows.count { |r| r[:suggested] == id }
          next if actual.zero? && predicted.zero?

          hits = rows.count { |r| r[:final] == id && r[:suggested] == id }
          { slug:, requests: actual, suggested: predicted, recall: ratio(hits, actual), precision: ratio(hits, predicted) }
        end.sort_by { |c| -c[:requests] },
        confusions: rows.select { |r| r[:suggested] && r[:suggested] != r[:final] }
                        .group_by { |r| [ r[:suggested], r[:final] ] }
                        .map { |(s, f), list| { suggested: slugs[s], chosen: slugs[f], count: list.size } }
                        .sort_by { |c| -c[:count] }.first(10),
        versions: rows.group_by { |r| [ r[:version], r[:model] ] }
                      .map { |(version, model), list| { prompt_version: version, model:, triaged: list.size, accuracy: accuracy(list) } }
                      .sort_by { |v| v[:prompt_version].to_s }.reverse,
        voice_notes: voice_notes(submitted)
      }
    end

    def accuracy(rows) = ratio(rows.count { |r| r[:suggested] && r[:suggested] == r[:final] }, rows.size)

    def ratio(part, whole) = whole.zero? ? nil : (part.to_f / whole).round(3)

    def voice_notes(requests)
      notes = RequestAttachment.voice_notes.where(service_request_id: requests.select(:id))
      counts = notes.group(:transcript_status).count
      { count: counts.values.sum, transcribed: counts.fetch("succeeded", 0), failed: counts.fetch("failed", 0),
        skipped: counts.fetch("skipped", 0) }
    end
  end
end
