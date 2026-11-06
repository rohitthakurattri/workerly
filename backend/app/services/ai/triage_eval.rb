module Ai
  # Offline evaluation of triage against config/ai/eval/triage.yml. Calls the adapter directly with
  # the production prompt (no gateway: no budget, cache or ai_analyses rows) so it can run against
  # a candidate model or prompt before switching. Text only; the set has no photos.
  module TriageEval
    module_function

    Case = Data.define(:text, :expect, :lang)
    Report = Data.define(:version, :prompt_version, :adapter, :model, :total, :correct, :accuracy, :by_category, :misses, :errors)

    def cases(path = Rails.root.join("config/ai/eval/triage.yml"))
      yaml = YAML.safe_load_file(path)
      [ yaml.fetch("version"), yaml.fetch("cases").map { |c| Case.new(text: c.fetch("text"), expect: c["expect"], lang: c.fetch("lang", "en")) } ]
    end

    def call(adapter: Adapters::Ai.adapter, model: Workerly.config.ai_triage_model, path: Rails.root.join("config/ai/eval/triage.yml"))
      version, list = cases(path)
      prompt = Prompts.fetch("triage")
      categories = ServiceCategory.requestable.order(:sort, :id).map { |c| "#{c.slug}: #{c.name('en')}" }.join("\n")
      results = list.map do |c|
        vars = { categories:, language: TriageRequest::LANGUAGES.fetch(c.lang, "English"), photo_note: "No photos attached.",
                 description: Shared::Redact.call(c.text) }
        response = adapter.complete(use_case: "triage", system: prompt.system, user: prompt.render(vars), vars:, schema: prompt.schema,
                                    images: [], model:, timeout: Gateway::TIMEOUTS.fetch("triage"))
        got = response.output["category_slug"].presence
        { case: c, got:, ok: got == c.expect }
      rescue Adapters::Ai::Error => e
        { case: c, got: nil, ok: false, error: e.code }
      end

      correct = results.count { |r| r[:ok] }
      Report.new(
        version:, prompt_version: prompt.version, adapter: adapter.name, model:, total: results.size, correct:,
        accuracy: results.empty? ? 0.0 : (correct.to_f / results.size).round(3),
        by_category: results.group_by { |r| r[:case].expect.to_s }.transform_values { |rs| { total: rs.size, correct: rs.count { |r| r[:ok] } } },
        misses: results.reject { |r| r[:ok] || r[:error] }.map { |r| { text: r[:case].text, expect: r[:case].expect, got: r[:got] } },
        errors: results.select { |r| r[:error] }.map { |r| { text: r[:case].text, error: r[:error] } }
      )
    end
  end
end
