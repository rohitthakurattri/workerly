require "net/http"

module Adapters
  module Sms
    # MSG91 "Send SMS" (v5 flow) with DLT-approved templates:
    #   POST https://control.msg91.com/api/v5/flow   header authkey
    #   { template_id, short_url: "0", recipients: [{ mobiles: "91XXXXXXXXXX", <var>: "value" }] }
    # Each config/sms_templates.yml key maps to an MSG91 template id via MSG91_TEMPLATE_<KEY>;
    # the template's variables are named like ours (##code##, ##category##, ##locality##).
    class Msg91
      ENDPOINT = URI("https://control.msg91.com/api/v5/flow")
      TIMEOUT = 10

      def self.template_env(key) = "MSG91_TEMPLATE_#{key.to_s.upcase}"

      # Template keys with no MSG91 id in the environment (the production boot check uses this).
      def self.missing_templates(env = ENV) = Sms.templates.keys.reject { |k| env[template_env(k)].present? }

      def initialize(auth_key: ENV["MSG91_AUTH_KEY"], sender: ENV["MSG91_SENDER_ID"], env: ENV)
        @auth_key = auth_key
        @sender = sender
        @env = env
      end

      def name = "msg91"

      def deliver(to:, message:)
        raise Error.new(:not_configured, "MSG91_AUTH_KEY is not set") if @auth_key.blank?

        template_id = @env[self.class.template_env(message.template)]
        raise Error.new(:not_configured, "#{self.class.template_env(message.template)} is not set") if template_id.blank?

        mobile = to.to_s.delete_prefix("+")
        raise Error.new(:invalid_number, "expected an Indian number in E.164") unless mobile.match?(/\A91[6-9]\d{9}\z/)

        body = { template_id:, short_url: "0", recipients: [ { mobiles: mobile, **message.vars } ] }
        body[:sender] = @sender if @sender.present? # only needed when the template's sender is "FromAPI"
        result = post(body)
        unless result["type"] == "success"
          # Bad auth key, unknown or unapproved template, missing variable: retrying won't help.
          raise Error.new(:rejected, "MSG91: #{result['message'].to_s.truncate(200)}")
        end

        true
      end

      private

      def post(body)
        request = Net::HTTP::Post.new(ENDPOINT, "authkey" => @auth_key, "Content-Type" => "application/json", "Accept" => "application/json")
        request.body = body.to_json
        http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
        http.use_ssl = true
        http.open_timeout = 3
        http.read_timeout = TIMEOUT
        http.write_timeout = TIMEOUT
        response = http.request(request)
        raise Error.new(:provider_error, "MSG91 HTTP #{response.code}") if response.code.to_i >= 500 || response.code == "429"

        JSON.parse(response.body.to_s)
      rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
        raise Error.new(:timeout)
      rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError
        raise Error.new(:network)
      rescue JSON::ParserError
        raise Error.new(:provider_error, "MSG91 answered with something other than JSON (HTTP #{response&.code})")
      end
    end
  end
end
