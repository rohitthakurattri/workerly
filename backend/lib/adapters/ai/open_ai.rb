require "net/http"

module Adapters
  module Ai
    # OpenAI Chat Completions with Structured Outputs (strict JSON schema). Images are sent
    # inline as base64 data URLs, never as links to our private bucket.
    class OpenAi
      ENDPOINT = URI("https://api.openai.com/v1/chat/completions")
      TRANSCRIPTIONS = URI("https://api.openai.com/v1/audio/transcriptions")
      EXTENSIONS = { "audio/webm" => "webm", "video/webm" => "webm", "audio/ogg" => "ogg", "audio/mp4" => "m4a",
                     "audio/x-m4a" => "m4a", "video/mp4" => "mp4", "audio/mpeg" => "mp3", "audio/wav" => "wav", "audio/x-wav" => "wav" }.freeze

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
        request = Net::HTTP::Post.new(ENDPOINT, "Content-Type" => "application/json")
        request.body = body.to_json
        parse(post(request, timeout))
      end

      # Speech to text. The audio goes in the request body (multipart), never as a link to our bucket.
      def transcribe(audio:, content_type:, language:, prompt:, model:, timeout:)
        raise Error.new(:not_configured, "OPENAI_API_KEY and a model are required") if @api_key.blank? || model.blank?

        filename = "voice-note.#{EXTENSIONS.fetch(content_type, 'webm')}"
        fields = { "model" => model, "response_format" => "json", "prompt" => prompt.to_s }
        fields["language"] = language if %w[en hi pa].include?(language)
        boundary = "workerly-#{SecureRandom.hex(12)}"
        request = Net::HTTP::Post.new(TRANSCRIPTIONS, "Content-Type" => "multipart/form-data; boundary=#{boundary}")
        request.body = multipart(boundary, fields, file: audio, filename:, content_type:)
        json = post(request, timeout)
        text = json["text"]
        raise Error.new(:invalid_output) unless text.is_a?(String)

        usage = json["usage"] || {}
        Response.new(output: { "text" => text, "language" => language }, model:,
                     input_tokens: usage["input_tokens"], output_tokens: usage["output_tokens"],
                     audio_seconds: usage["type"] == "duration" ? usage["seconds"] : nil)
      end

      private

      def multipart(boundary, fields, file:, filename:, content_type:)
        body = +"".b
        fields.each do |name, value|
          body << "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n\r\n".b << value.to_s.b << "\r\n".b
        end
        body << "--#{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n".b
        body << "Content-Type: #{content_type}\r\n\r\n".b << file.b << "\r\n--#{boundary}--\r\n".b
      end

      def post(request, timeout)
        http = Net::HTTP.new(request.uri.host, request.uri.port)
        http.use_ssl = true
        http.open_timeout = 3
        http.read_timeout = timeout
        http.write_timeout = timeout
        request["Authorization"] = "Bearer #{@api_key}"
        response = http.request(request)
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
