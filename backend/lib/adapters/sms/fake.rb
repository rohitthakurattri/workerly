module Adapters
  module Sms
    # Development/test adapter: logs the message and keeps it in memory for specs.
    class Fake
      Delivery = Data.define(:to, :body)

      def self.deliveries = (@deliveries ||= [])

      def deliver(to:, body:)
        self.class.deliveries << Delivery.new(to:, body:)
        # Staging only (production refuses to boot with this adapter): testers read their code
        # from the log, as there is no real SMS yet (D6).
        if Rails.env.production?
          Rails.logger.warn("[FakeSms] staging code to=#{to} body=#{body.lines.first.strip}") if Workerly.config.deploy_env == "staging"
          return true
        end

        Rails.logger.info("[FakeSms] to=#{to} body=#{body.lines.first.strip}")
        # Local inbox for manual testing and the Playwright smoke test (tail -f log/fake_sms.log).
        File.open(Rails.root.join("log/fake_sms.log"), "a") { |f| f.puts("#{Time.current.iso8601} #{to} #{body.lines.first.strip}") } if Rails.env.development?
        true
      end
    end
  end
end
