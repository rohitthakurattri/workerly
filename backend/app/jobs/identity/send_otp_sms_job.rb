module Identity
  class SendOtpSmsJob < ApplicationJob
    queue_as :critical
    # Arguments are the phone number and the code; keep them out of job logs.
    self.log_arguments = false
    # An OTP is worthless after 5 minutes, so retry briefly and then give up.
    retry_on StandardError, wait: 5.seconds, attempts: 3

    def perform(phone, code)
      Adapters::Sms.adapter.deliver(to: phone, message: Adapters::Sms.otp_message(code))
    rescue Adapters::Sms::Error => e
      raise if e.retryable?

      # Misconfiguration or a refused template: retrying won't help, and the customer can ask again.
      Rails.logger.error("[SendOtpSms] not sent: #{e.code} #{e.message}")
    end
  end
end
