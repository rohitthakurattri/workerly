module Identity
  class SendOtpSmsJob < ApplicationJob
    queue_as :critical
    # Arguments are the phone number and the code; keep them out of job logs.
    self.log_arguments = false
    # An OTP is worthless after 5 minutes, so retry briefly and then give up.
    retry_on StandardError, wait: 5.seconds, attempts: 3

    def perform(phone, code)
      Adapters::Sms.adapter.deliver(to: phone, body: Adapters::Sms.otp_message(code))
    end
  end
end
