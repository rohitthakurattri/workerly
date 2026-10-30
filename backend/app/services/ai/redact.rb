module Ai
  # Removes contact details before customer text leaves Workerly. Names and exact addresses are
  # never sent in the first place; this catches what customers type into the description.
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
