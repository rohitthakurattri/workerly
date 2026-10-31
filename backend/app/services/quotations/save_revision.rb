module Quotations
  # Inserts a built revision and its lines under an existing quotation.
  module SaveRevision
    module_function

    def call(quotation, draft)
      revision = draft.revision
      revision.quotation = quotation
      revision.save!
      draft.items.each do |item|
        item.quotation_revision = revision
        item.save!
      end
      revision
    end
  end
end
