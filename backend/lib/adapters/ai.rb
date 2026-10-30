module Adapters
  # AI provider port: complete(use_case:, system:, user:, vars:, images:, schema:, model:, timeout:) -> Response.
  # Business code never calls an adapter directly; it goes through Ai::Gateway.
  module Ai
    Response = Data.define(:output, :model, :input_tokens, :output_tokens)

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
