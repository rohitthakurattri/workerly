module Adapters
  # SMS gateway port. Real providers (MSG91 / Twilio Verify) plug in here once D6 is
  # decided and DLT templates are registered.
  module Sms
    def self.adapter
      case Workerly.config.sms_adapter
      when "fake" then Fake.new
      else raise ArgumentError, "Unknown SMS_ADAPTER #{Workerly.config.sms_adapter.inspect}"
      end
    end

    # Template text must match the DLT-registered template exactly.
    # The last line lets Android/Chrome autofill the code (WebOTP).
    def self.otp_message(code)
      "#{code} is your Workerly login code. It is valid for 5 minutes. Do not share it with anyone.\n\n@workerly.in ##{code}"
    end
  end
end
