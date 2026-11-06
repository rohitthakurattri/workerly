module Adapters
  # Payment gateway port. "fake" in development and test (and until Razorpay keys exist);
  # "razorpay" uses Orders, Refunds and signed webhooks. Route transfers wait for D3.
  module Payments
    class Error < StandardError
      attr_reader :code

      def initialize(code, message = nil)
        @code = code
        super(message || code.to_s)
      end
    end

    def self.adapter
      case Workerly.config.payment_adapter
      when "fake" then Fake.new
      when "razorpay" then Razorpay.new
      else raise ArgumentError, "Unknown PAYMENT_ADAPTER #{Workerly.config.payment_adapter.inspect}"
      end
    end

    # Razorpay's scheme for both the checkout callback and webhooks: hex HMAC-SHA256.
    def self.hmac(secret, data) = OpenSSL::HMAC.hexdigest("SHA256", secret, data)

    def self.secure_compare(a, b) = a.present? && b.present? && ActiveSupport::SecurityUtils.secure_compare(a, b)
  end
end
