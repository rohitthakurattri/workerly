require "net/http"

module Adapters
  module Ai
    # OpenAI Chat Completions with Structured Outputs (strict JSON schema). Images are sent
    # inline as base64 data URLs, never as links to our private bucket.
    class OpenAi
      ENDPOINT = URI("https://api.openai.com/v1/chat/completions")

      def initialize(api_key: ENV["OPENAI_API_KEY"])
        @api_key = api_key
      end

      def name = "openai"
      def supports_images? = true

      def complete(use_case:, system:, user:, schema:, model:, timeout:, images: [], **)
        raise Error.new(:not_configured, "OPENAI_API_KEY and a model are required") if @api_key.blank? || model.blank?

        content = [ { type: "text", text: user } ] + images.map do |image|
          { type: "image_url", image_url: { url: "data:#{image[:content_type]};base64,#{image[:data]}", detail: "low" } }
        end
        body = {
          model:,
          messages: [ { role: "system", content: system }, { role: "user", content: } ],
          response_format: { type: "json_schema", json_schema: { name: use_case, strict: true, schema: } }
        }
        parse(post(body, timeout))
      end

      private

      def post(body, timeout)
        http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
        http.use_ssl = true
        http.open_timeout = 3
        http.read_timeout = timeout
        http.write_timeout = timeout
        response = http.post(ENDPOINT.path, body.to_json,
                             "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json")
        raise Error.new(:rate_limited) if response.code == "429"
        raise Error.new(:provider_error, "HTTP #{response.code}") unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
        raise Error.new(:timeout)
      rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError
        raise Error.new(:network)
      rescue JSON::ParserError
        raise Error.new(:provider_error, "response was not JSON")
      end

      def parse(json)
        message = json.dig("choices", 0, "message") || {}
        raise Error.new(:refused) if message["refusal"].present?

        output = JSON.parse(message["content"].to_s)
        raise Error.new(:invalid_output) unless output.is_a?(Hash)

        Response.new(output:, model: json["model"], input_tokens: json.dig("usage", "prompt_tokens"),
                     output_tokens: json.dig("usage", "completion_tokens"))
      rescue JSON::ParserError
        raise Error.new(:invalid_output)
      end
    end
  end
end
