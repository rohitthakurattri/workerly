# History and money tables are written once and never changed. The app already refuses
# (AppendOnly); these triggers make Postgres refuse too, for every client: console, rake task,
# raw SQL, update_all/delete_all, a future service that forgets the concern.
#
# Escape hatch for an operator with DB access (e.g. a legal erasure request), one transaction only:
#   BEGIN; SET LOCAL workerly.allow_history_rewrite = 'on'; ...; COMMIT;
class EnforceAppendOnlyTables < ActiveRecord::Migration[8.1]
  TABLES = %w[
    admin_actions ai_analyses booking_approvals booking_status_histories invoices
    ledger_entries ledger_transactions messages payment_events quotation_items
    quotation_revisions reviews worker_payouts worker_verifications
  ].freeze

  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION workerly_append_only() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF current_setting('workerly.allow_history_rewrite', true) = 'on' THEN
          IF TG_LEVEL = 'STATEMENT' THEN RETURN NULL; END IF;
          IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
          RETURN NEW;
        END IF;
        RAISE EXCEPTION '% on % refused: the table is append-only', TG_OP, TG_TABLE_NAME
          USING ERRCODE = 'WK001', HINT = 'Write a new row instead (reversal, new revision, new rule).';
      END;
      $$;
    SQL

    TABLES.each do |table|
      execute <<~SQL
        CREATE TRIGGER workerly_append_only BEFORE UPDATE OR DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION workerly_append_only();
        CREATE TRIGGER workerly_append_only_truncate BEFORE TRUNCATE ON #{table}
          FOR EACH STATEMENT EXECUTE FUNCTION workerly_append_only();
      SQL
    end
  end

  def down
    TABLES.each do |table|
      execute "DROP TRIGGER IF EXISTS workerly_append_only ON #{table}; DROP TRIGGER IF EXISTS workerly_append_only_truncate ON #{table};"
    end
    execute "DROP FUNCTION IF EXISTS workerly_append_only();"
  end
end
