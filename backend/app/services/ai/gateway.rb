module Ai
  # The only way business code reaches an AI provider. Applies the timeout, circuit breaker,
  # per-user and global daily budgets and the input cache, and logs every call to ai_analyses.
  module Gateway
    module_function

    TIMEOUTS = { "triage" => 8, "transcribe" => 30 }.freeze
    CACHE_TTL = 7.days
    BREAKER_FAILURES = 5
    BREAKER_WINDOW = 1.minute

    Result = Data.define(:analysis, :output)

    # vars: strings for the prompt template; image_keys: stable ids (blob checksums) of the images.
    # images: a lambda returning [{ content_type:, data: (base64) }], only called on a real provider call.
    # extract: output -> { suggested_category_id:, confidence: } stored on the analysis row.
    # invoke: (adapter, prompt, model, timeout) -> Adapters::Ai::Response, for ports other than complete
    #         (transcription); image_keys then identify the input (the audio's checksum).
    def call(use_case:, analysable:, user:, vars:, image_keys: [], images: -> { [] }, extract: ->(_) { {} },
             adapter: Adapters::Ai.adapter, invoke: nil)
      prompt = Prompts.fetch(use_case)
      model = model_for(use_case)
      input_hash = Digest::SHA256.hexdigest([ prompt.version, adapter.name, model, prompt.render(vars), *image_keys ].join("\u0000"))
      base = { analysable:, user:, use_case:, provider: adapter.name, prompt_version: prompt.version, input_hash: }

      if (hit = cache_hit(use_case, input_hash))
        analysis = AiAnalysis.create!(base.merge(status: "succeeded", cached: true, model: hit.model, output: hit.output,
                                                 suggested_category_id: hit.suggested_category_id, confidence: hit.confidence,
                                                 latency_ms: 0))
        return Result.new(analysis:, output: hit.output)
      end

      ensure_breaker_closed!(adapter.name)
      ensure_budget!(use_case, user)

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        timeout = TIMEOUTS.fetch(use_case)
        response = if invoke
          invoke.call(adapter, prompt, model, timeout)
        else
          adapter.complete(use_case:, system: prompt.system, user: prompt.render(vars), vars:, schema: prompt.schema,
                           images: adapter.supports_images? ? images.call : [], model:, timeout:)
        end
      rescue Adapters::Ai::Error => e
        AiAnalysis.create!(base.merge(status: "failed", model:, error_code: e.code, latency_ms: elapsed_ms(started)))
        Rails.logger.warn("[Ai::Gateway] #{use_case} via #{adapter.name} failed: #{e.code}")
        raise ApplicationError.new(:ai_unavailable, status: :service_unavailable)
      end

      analysis = AiAnalysis.create!(base.merge(
        status: "succeeded", model: response.model || model, output: response.output, latency_ms: elapsed_ms(started),
        input_tokens: response.input_tokens, output_tokens: response.output_tokens,
        **cost(adapter.name, response), **extract.call(response.output)
      ))
      Result.new(analysis:, output: response.output)
    end

    def model_for(use_case)
      case use_case
      when "triage" then Workerly.config.ai_triage_model
      when "transcribe" then Workerly.config.ai_transcribe_model
      end
    end

    def cache_hit(use_case, input_hash)
      AiAnalysis.succeeded.where(use_case:, input_hash:).where(created_at: CACHE_TTL.ago..).order(created_at: :desc).first
    end

    # Fail fast while the provider is failing, instead of making every customer wait for the timeout.
    def ensure_breaker_closed!(provider)
      recent = AiAnalysis.failed.where(provider:, created_at: BREAKER_WINDOW.ago..).count
      raise ApplicationError.new(:ai_unavailable, status: :service_unavailable) if recent >= BREAKER_FAILURES
    end

    # Cache hits are free and don't count; failed calls do (they may still be billed).
    def ensure_budget!(use_case, user)
      calls = AiAnalysis.where(use_case:, cached: false, created_at: 1.day.ago..)
      if calls.count >= Workerly.config.ai_global_daily_limit
        Rails.logger.error("[Ai::Gateway] global daily AI limit reached for #{use_case}")
        raise ApplicationError.new(:ai_unavailable, status: :service_unavailable)
      end
      return unless user && calls.where(user:).count >= Workerly.config.ai_user_daily_limit

      raise ApplicationError.too_many_requests(:ai_budget_exceeded)
    end

    # Token prices (per million), or per_minute for speech-to-text billed by duration.
    def cost(provider, response)
      price = pricing["#{provider}/#{response.model}"]
      if price && price["per_minute"] && response.audio_seconds
        return { cost_micros: (response.audio_seconds.to_f / 60 * price["per_minute"]).round, currency_code: price["currency"] }
      end
      return {} unless price && response.input_tokens && response.output_tokens

      micros = (response.input_tokens * price["input"] + response.output_tokens * price["output"]) / 1_000_000
      { cost_micros: micros.round, currency_code: price["currency"] }
    end

    def pricing = (@pricing ||= YAML.safe_load_file(Rails.root.join("config/ai/pricing.yml")) || {})

    def elapsed_ms(started) = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  end
end
