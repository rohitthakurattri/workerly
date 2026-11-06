class InvoiceSequence < ApplicationRecord
  # Next gapless number in a series (one series per financial year), under a row lock.
  def self.next!(series)
    insert_all([ { series:, last_number: 0 } ], unique_by: :series)
    seq = lock.find_by!(series:)
    seq.update_columns(last_number: seq.last_number + 1)
    seq.last_number
  end
end
