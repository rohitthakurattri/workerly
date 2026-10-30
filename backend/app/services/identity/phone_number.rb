module Identity
  # Normalises user-typed Indian mobile numbers to E.164. Launch is India-only.
  module PhoneNumber
    E164 = /\A\+[1-9]\d{7,14}\z/
    INDIAN_MOBILE = /\A[6-9]\d{9}\z/

    module_function

    # "98765 43210", "098765-43210", "+91 98765 43210", "919876543210" -> "+919876543210"
    def normalize(input)
      digits = input.to_s.gsub(/[^\d+]/, "")
      digits = digits.delete_prefix("+91").delete_prefix("0091")
      digits = digits.delete_prefix("91") if digits.length == 12
      digits = digits.delete_prefix("0") if digits.length == 11
      INDIAN_MOBILE.match?(digits) ? "+91#{digits}" : nil
    end

    def normalize!(input)
      normalize(input) || raise(ApplicationError.new(:invalid_phone, details: { field_errors: { phone: [ "is not a valid Indian mobile number" ] } }))
    end

    def mask(e164) = "#{e164[0..2]}******#{e164[-4..]}"
  end
end
