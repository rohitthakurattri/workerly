module Adapters
  # AI provider port. Business code never calls an adapter directly; it goes through Ai::Gateway.
  #   complete(use_case:, system:, user:, vars:, images:, schema:, model:, timeout:) -> Response
  #   transcribe(audio:, content_type:, language:, prompt:, model:, timeout:) -> Response
  #     output: { "text" => String, "language" => String|nil }; audio_seconds when the provider reports it
  module Ai
    Response = Data.define(:output, :model, :input_tokens, :output_tokens, :audio_seconds) do
      def initialize(output:, model:, input_tokens: nil, output_tokens: nil, audio_seconds: nil) = super
    end

    # code: timeout | network | rate_limited | provider_error | refused | invalid_output | not_configured
    class Error < StandardError
      attr_reader :code

      def initialize(code, message = nil)
        @code = code.to_s
        super(message || @code)
      end
    end

    def self.adapter(name = Workerly.config.ai_adapter)
      case name
      when "fake" then Fake.new
      when "openai" then OpenAi.new
      else raise ArgumentError, "Unknown AI_ADAPTER #{name.inspect}"
      end
    end
  end
end
