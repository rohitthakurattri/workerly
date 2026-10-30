module Ai
  # Suggests a category, a summary and follow-up questions for a draft request. Suggestions only:
  # the customer confirms or changes the category before anything is submitted.
  module TriageRequest
    module_function

    LOW_CONFIDENCE = 0.6
    MAX_IMAGES = 3
    IMAGE_SIZE = 1024
    MAX_QUESTIONS = 4
    LANGUAGES = { "en" => "English", "hi" => "Hindi (Devanagari script)", "pa" => "Punjabi (Gurmukhi script)" }.freeze

    Suggestion = Data.define(:analysis, :category, :confidence, :alternatives, :summary, :questions, :urgency, :safety_flag) do
      def needs_confirmation? = category.nil? || confidence < LOW_CONFIDENCE
    end

    def call(request:, user:)
      raise ApplicationError.new(:ai_unavailable, status: :service_unavailable) unless Workerly.config.ai_triage_enabled

      description = Redact.call(request.description)
      photos = request.photos.first(MAX_IMAGES)
      raise ApplicationError.new(:nothing_to_analyse) if description.length < ServiceRequest::DESCRIPTION_MIN && photos.empty?

      categories = ServiceCategory.requestable.order(:sort, :id).to_a
      by_slug = categories.index_by(&:slug)
      vars = {
        categories: categories.map { |c| "#{c.slug}: #{c.name('en')}" }.join("\n"),
        language: LANGUAGES.fetch(user.locale, "English"),
        photo_note: photos.any? ? "The customer attached #{photos.size} photo(s)." : "No photos attached.",
        description: description.presence || "(no text, see photos)"
      }
      result = Gateway.call(
        use_case: "triage", analysable: request, user:, vars:,
        image_keys: photos.map { |p| p.file.blob.checksum }, images: -> { photos.map { |p| downscale(p.file) } },
        extract: ->(out) { { suggested_category_id: by_slug[out["category_slug"]]&.id, confidence: confidence(out) } }
      )

      suggestion = build(result, by_slug)
      request.update!(triage_analysis: result.analysis, ai_summary: suggestion.summary, safety_flag: suggestion.safety_flag)
      suggestion
    end

    # Never trust model output: unknown slugs are dropped and everything is clipped to size.
    def build(result, by_slug)
      out = result.output
      category = by_slug[out["category_slug"]]
      alternatives = Array(out["alternatives"]).filter_map { |s| by_slug[s] }.uniq.reject { |c| c == category }.first(3)
      questions = Array(out["follow_up_questions"]).grep(String).map { |q| q.strip.truncate(200) }.reject(&:blank?).first(MAX_QUESTIONS)
      urgency = ServiceRequest::URGENCIES.include?(out["urgency"]) ? out["urgency"] : nil
      Suggestion.new(analysis: result.analysis, category:, confidence: category ? confidence(out) : 0.0, alternatives:,
                     summary: out["problem_summary"].to_s.strip.truncate(500).presence, questions:, urgency:,
                     safety_flag: out["safety_flag"] == true)
    end

    def confidence(out) = out["confidence"].to_f.clamp(0.0, 1.0).round(3)

    def downscale(attachment)
      attachment.blob.open do |file|
        out = ImageProcessing::MiniMagick.source(file.path).resize_to_limit(IMAGE_SIZE, IMAGE_SIZE).saver(quality: 75).convert("jpg").call
        { content_type: "image/jpeg", data: Base64.strict_encode64(File.binread(out.path)) }
      ensure
        out&.close!
      end
    end
  end
end
