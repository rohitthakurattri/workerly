# History tables are written once and never changed. Enforced in the app for now;
# a DB trigger follows when the schema moves to structure.sql (needed for the ledger in Phase 7).
module AppendOnly
  extend ActiveSupport::Concern

  included do
    before_destroy { raise ActiveRecord::ReadOnlyRecord, "#{self.class.name} is append-only" }
  end

  def readonly? = persisted? || super
end
