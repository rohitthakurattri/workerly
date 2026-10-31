module Shared
  # Removes contact details from customer text before it goes to an AI provider or to workers
  # who haven't been booked (off-platform leakage). Names and exact addresses are never included.
  module Redact
    module_function

    PHONE = /(?:\+?91[\s-]?)?(?<!\d)[6-9]\d{4}[\s-]?\d{5}(?!\d)/
    EMAIL = /[\w.+-]+@[\w-]+\.[\w.-]+/
    MARKERS = /<<<|>>>|CUSTOMER_TEXT/

    def call(text)
      text.to_s.gsub(PHONE, "[phone removed]").gsub(EMAIL, "[email removed]").gsub(MARKERS, "").strip
    end
  end
end
