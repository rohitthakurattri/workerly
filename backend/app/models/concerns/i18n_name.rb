# Reads a jsonb { "en": ..., "hi": ..., "pa": ... } column, falling back to English.
module I18nName
  extend ActiveSupport::Concern

  class_methods do
    def i18n_attribute(*columns)
      columns.each do |column|
        base = column.to_s.delete_suffix("_i18n")
        define_method(base) do |locale = I18n.locale|
          values = public_send(column) || {}
          values[locale.to_s].presence || values["en"]
        end
      end
    end
  end
end
