module Quotations
  # Turns a worker's quote form into a validated, priced revision (not saved). Prices are always
  # computed here, never taken from the client.
  #
  #   fixed:      { kind: "fixed", items: [{ type, description, brand, quantity, unit, unit_price_minor,
  #                 condition, warranty_days }], notes, estimated_minutes }
  #   inspection: { kind: "inspection", inspection_fee_minor, notes, estimated_minutes }
  module Build
    module_function

    MAX_ITEMS = 30
    MAX_TOTAL_MINOR = 50_000_000 # ₹5,00,000: above this, support quotes it by hand
    Draft = Data.define(:kind, :revision, :items)

    def call(params:, request:, actor:, version:)
      kind = params[:kind].to_s
      errors = {}
      errors["kind"] = [ "must be fixed or inspection" ] unless Quotation::KINDS.include?(kind)
      category = request.service_category
      if kind == "inspection" && !category.inspection_allowed
        raise ApplicationError.new(:inspection_not_allowed, details: { category: category.slug })
      end

      items = kind == "inspection" ? [ inspection_item(params) ] : fixed_items(params[:items], errors)
      items.each_with_index do |item, i|
        item.position = i + 1
        item.amount_minor = line_amount(item.quantity, item.unit_price_minor)
        item.validate
        item.errors.add(:item_type, "inspection fee goes in an inspection quote") if kind == "fixed" && item.item_type == "inspection"
        item.errors.each do |e|
          next if e.attribute == :quotation_revision

          key = kind == "inspection" ? "inspection_fee_minor" : "items.#{i}.#{public_field(e.attribute)}"
          (errors[key] ||= []) << e.message
        end
      end

      subtotal = items.sum { |i| i.amount_minor.to_i }
      tax_rate_bps = category.tax_rate_bps
      tax = tax_for(subtotal, tax_rate_bps)
      revision = QuotationRevision.new(
        version:, stage: kind == "inspection" ? "inspection_fee" : "initial", created_by: actor,
        subtotal_minor: subtotal, tax_rate_bps:, tax_minor: tax, total_minor: subtotal + tax,
        currency_code: request.city.currency_code,
        notes: params[:notes].presence && Shared::Redact.call(params[:notes].to_s),
        estimated_minutes: params[:estimated_minutes].presence&.to_i
      )
      revision.validate
      revision.errors.each { |e| (errors[e.attribute.to_s] ||= []) << e.message unless e.attribute == :quotation }
      errors["total"] = [ "must be more than zero" ] if kind == "fixed" && revision.total_minor <= 0
      errors["total"] = [ "must be at most #{Shared::Money.format(MAX_TOTAL_MINOR, revision.currency_code)}" ] if revision.total_minor > MAX_TOTAL_MINOR
      raise ApplicationError.new(:validation_failed, details: { field_errors: errors }) if errors.any?

      Draft.new(kind:, revision:, items:)
    end

    # quantity × unit price, rounded half up to the minor unit.
    def line_amount(quantity, unit_price_minor)
      return 0 if quantity.nil? || unit_price_minor.nil?

      (BigDecimal(quantity.to_s) * unit_price_minor).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def tax_for(subtotal, bps) = ((subtotal * bps) + 5_000) / 10_000

    def fixed_items(raw, errors)
      list = raw.is_a?(Array) ? raw : []
      errors["items"] = [ "add at least one line" ] if list.empty?
      errors["items"] = [ "at most #{MAX_ITEMS} lines" ] if list.size > MAX_ITEMS
      list.first(MAX_ITEMS).map do |i|
        i = i.respond_to?(:to_unsafe_h) ? i.to_unsafe_h : i.to_h
        i = i.with_indifferent_access
        QuotationItem.new(
          item_type: i[:type].to_s, description: Shared::Redact.call(i[:description].to_s), brand: i[:brand].to_s.strip.presence,
          quantity: decimal(i[:quantity]), unit: i[:unit].to_s.presence || "job", unit_price_minor: integer(i[:unit_price_minor]),
          condition: i[:type].to_s == "material" ? i[:condition].to_s.presence : nil,
          warranty_days: integer(i[:warranty_days])
        )
      end
    end

    def inspection_item(params)
      QuotationItem.new(item_type: "inspection", description: "Inspection visit", quantity: 1, unit: "visit",
                        unit_price_minor: integer(params[:inspection_fee_minor]))
    end

    def decimal(v)
      v.present? ? BigDecimal(v.to_s) : nil
    rescue ArgumentError
      nil
    end

    def integer(v) = v.present? && v.to_s.match?(/\A-?\d+\z/) ? v.to_i : nil

    def public_field(attr) = attr == :item_type ? "type" : attr.to_s
  end
end
