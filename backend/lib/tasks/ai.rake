namespace :ai do
  # bin/rails "ai:eval[triage]"  (AI_ADAPTER / AI_TRIAGE_MODEL pick what is evaluated)
  # Exits non-zero below AI_EVAL_MIN_ACCURACY (default 0.8), so it can gate a model or prompt change.
  desc "Run the labelled triage evaluation set against the configured adapter and model"
  task :eval, [ :use_case ] => :environment do |_, args|
    abort "Only triage has an evaluation set" unless args[:use_case].to_s.in?([ "", "triage" ])

    r = Ai::TriageEval.call
    puts "Triage eval #{r.version} · prompt #{r.prompt_version} · #{r.adapter}/#{r.model || '-'}"
    puts format("Accuracy: %<c>d/%<t>d = %<a>.1f%%", c: r.correct, t: r.total, a: r.accuracy * 100)
    r.by_category.sort.each { |slug, s| puts format("  %-18s %d/%d", slug.presence || "(none)", s[:correct], s[:total]) }
    r.misses.each { |m| puts "  miss: #{m[:text].inspect} expected #{m[:expect] || 'none'}, got #{m[:got] || 'none'}" }
    r.errors.each { |e| puts "  error: #{e[:text].inspect} #{e[:error]}" }
    min = ENV.fetch("AI_EVAL_MIN_ACCURACY", "0.8").to_f
    abort "Below the #{(min * 100).round}% bar" if r.accuracy < min
  end

  # bin/rails "ai:export_triage_cases[2026-11-01,2026-11-30]" > cases.jsonl
  # Real submitted requests as candidate eval cases: redacted text, the customer's language and the
  # category they chose. No names, addresses, photos or ids. Review every label before adding it.
  desc "Export submitted requests as candidate triage eval cases (JSON lines, redacted)"
  task :export_triage_cases, %i[from to] => :environment do |_, args|
    from = args[:from].present? ? Time.zone.parse(args[:from]) : 30.days.ago
    to = args[:to].present? ? Time.zone.parse(args[:to]).end_of_day : Time.current
    ServiceRequest.where(submitted_at: from..to).where.not(service_category_id: nil)
                  .includes(:service_category, :customer, :triage_analysis).find_each do |r|
      text = Shared::Redact.call(r.description)
      next if text.length < ServiceRequest::DESCRIPTION_MIN

      puts({ text:, expect: r.service_category.slug, lang: r.customer.locale, category_source: r.category_source,
             ai_suggested: r.triage_analysis&.suggested_category_id && ServiceCategory.find_by(id: r.triage_analysis.suggested_category_id)&.slug }.to_json)
    end
  end
end
