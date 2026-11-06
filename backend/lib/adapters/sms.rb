module Adapters
  # SMS gateway port: deliver(to: "+91…", message: Message) -> true, or raises Sms::Error.
  # Messages are built from config/sms_templates.yml only, because Indian DLT rules reject any
  # SMS that doesn't match a registered template.
  module Sms
    VAR_MAX = 30

    Template = Data.define(:key, :text, :vars)
    # template: the key in sms_templates.yml; vars: the clipped values; body: the rendered text
    # (what the fake adapter records and what DLT will match).
    Message = Data.define(:template, :vars, :body)

    # code: not_configured | invalid_number | rejected (the provider refused the request; don't
    # retry) | provider_error | timeout | network (worth retrying)
    class Error < StandardError
      RETRYABLE = %w[provider_error timeout network].freeze
      attr_reader :code

      def initialize(code, message = nil)
        @code = code.to_s
        super(message || @code)
      end

      def retryable? = RETRYABLE.include?(code)
    end

    def self.adapter(name = Workerly.config.sms_adapter)
      case name
      when "fake" then Fake.new
      when "msg91" then Msg91.new
      else raise ArgumentError, "Unknown SMS_ADAPTER #{name.inspect}"
      end
    end

    def self.templates
      @templates ||= YAML.safe_load_file(Rails.root.join("config/sms_templates.yml")).to_h do |key, t|
        [ key.to_sym, Template.new(key: key.to_sym, text: t.fetch("text"), vars: Array(t["vars"]).map(&:to_sym)) ]
      end
    end

    # Builds a registered message. Every declared variable must be given, and nothing else.
    def self.message(key, **vars)
      template = templates.fetch(key.to_sym) { raise ArgumentError, "Unknown SMS template #{key.inspect}" }
      unless vars.keys.sort == template.vars.sort
        raise ArgumentError, "SMS template #{key} takes #{template.vars.inspect}, got #{vars.keys.inspect}"
      end

      values = vars.transform_values { |v| v.to_s.squish.truncate(VAR_MAX, omission: "") }
      Message.new(template: template.key, vars: values, body: format(template.text, **values))
    end

    def self.otp_message(code) = message(:otp, code:)
  end
end
