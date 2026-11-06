module Ai
  # Speech to text for a draft's voice note, through the gateway (budget, breaker, cache by the
  # audio's checksum, ai_analyses log). The transcript is a suggestion: the customer decides
  # whether to add it to the description. Workers only ever see it redacted (Shared::Redact).
  module TranscribeVoiceNote
    module_function

    MAX_CHARS = 4000

    def call(attachment)
      return attachment unless attachment.audio? && attachment.transcript_status == "pending"

      request = attachment.service_request
      blob = attachment.file.blob
      language = request.customer.locale
      result = Gateway.call(
        use_case: "transcribe", analysable: request, user: request.customer, vars: { language: }, image_keys: [ blob.checksum ],
        invoke: lambda do |adapter, prompt, model, timeout|
          adapter.transcribe(audio: blob.download, content_type: blob.content_type, language:, prompt: prompt.system, model:, timeout:)
        end
      )
      text = result.output["text"].to_s.squish.truncate(MAX_CHARS)
      attachment.update!(transcript: text.presence, transcript_language: result.output["language"].to_s.first(8).presence,
                         transcript_status: text.present? ? "succeeded" : "failed", transcription_analysis: result.analysis)
      attachment
    rescue ApplicationError => e
      # ai_unavailable or the customer's daily budget: no transcript, the recording is still there.
      Rails.logger.info("[Ai::TranscribeVoiceNote] #{attachment.public_id}: #{e.code}")
      attachment.update!(transcript_status: "failed")
      attachment
    end
  end
end
