module Adapters
  module Sms
    # Development/test adapter: logs the message and keeps it in memory for specs.
    class Fake
      Delivery = Data.define(:to, :body)

      def self.deliveries = (@deliveries ||= [])

      def deliver(to:, body:)
        self.class.deliveries << Delivery.new(to:, body:)
        return true if Rails.env.production?

        Rails.logger.info("[FakeSms] to=#{to} body=#{body.lines.first.strip}")
        # Local inbox for manual testing and the Playwright smoke test (tail -f log/fake_sms.log).
        File.open(Rails.root.join("log/fake_sms.log"), "a") { |f| f.puts("#{Time.current.iso8601} #{to} #{body.lines.first.strip}") } if Rails.env.development?
        true
      end
    end
  end
end
