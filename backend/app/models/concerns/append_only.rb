# History and money tables are written once and never changed. The app refuses here, and
# Postgres refuses too (workerly_append_only triggers, db/migrate/20261106120000_*), for any client.
module AppendOnly
  extend ActiveSupport::Concern

  included do
    before_destroy { raise ActiveRecord::ReadOnlyRecord, "#{self.class.name} is append-only" }
  end

  def readonly? = persisted? || super

  # Retention and legal erasure only (e.g. purging an abandoned draft's AI log): lets the block
  # delete or change append-only rows. Runs in a savepoint; the permission is switched off again
  # when the block finishes (and reverts with the savepoint if it raises), so it never leaks into
  # the rest of an enclosing transaction.
  def self.rewriting
    conn = ActiveRecord::Base.connection
    conn.transaction(requires_new: true) do
      conn.execute("SET LOCAL workerly.allow_history_rewrite = 'on'")
      result = yield
      conn.execute("SET LOCAL workerly.allow_history_rewrite = 'off'")
      result
    end
  end
end
