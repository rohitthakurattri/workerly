require "rails_helper"

# Postgres itself refuses to change history and money rows (db/migrate/*_enforce_append_only_tables.rb),
# whatever the client: raw SQL, update_all/delete_all, a console.
RSpec.describe "Append-only tables (DB triggers)", type: :service do
  let!(:mohali) { create(:mohali) }
  let!(:rule) { CommissionRule.create!(percent_bps: 1000, fixed_minor: 0, effective_from: 1.year.ago) }
  let(:conn) { ActiveRecord::Base.connection }

  # Each attempt runs in a savepoint, so the refusal doesn't abort the test's transaction.
  def refused?(sql)
    ActiveRecord::Base.transaction(requires_new: true) { conn.execute(sql) }
    false
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.include?("append-only")

    true
  end

  def triggered_tables(name)
    conn.select_values(<<~SQL)
      SELECT DISTINCT c.relname FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
      WHERE t.tgname = '#{name}' AND NOT t.tgisinternal ORDER BY 1
    SQL
  end

  it "covers exactly the tables whose models are AppendOnly (row and TRUNCATE triggers)" do
    Rails.application.eager_load!
    tables = ActiveRecord::Base.descendants.select { |m| m.include?(AppendOnly) && !m.abstract_class? }.map(&:table_name).uniq.sort
    expect(tables.size).to be >= 14
    expect(triggered_tables("workerly_append_only")).to eq(tables)
    expect(triggered_tables("workerly_append_only_truncate")).to eq(tables)
  end

  context "with a paid booking (ledger, invoice, payment event, approvals, history)" do
    let!(:booking) { completed_booking!(amount_minor: 95_000).tap { |b| pay_online!(b) } }

    {
      "ledger_entries" => "amount_minor = amount_minor + 1",
      "ledger_transactions" => "created_at = now()",
      "invoices" => "total_minor = 0",
      "payment_events" => "processed_at = NULL",
      "booking_approvals" => "decision = 'rejected'",
      "booking_status_histories" => "to_status = 'cancelled'",
      "quotation_revisions" => "total_minor = 1",
      "quotation_items" => "amount_minor = 1"
    }.each do |table, set|
      it "refuses UPDATE, DELETE and TRUNCATE on #{table}" do
        expect(conn.select_value("SELECT count(*) FROM #{table}")).to be_positive
        expect(refused?("UPDATE #{table} SET #{set}")).to be(true)
        expect(refused?("DELETE FROM #{table}")).to be(true)
        expect(refused?("TRUNCATE #{table} CASCADE")).to be(true)
      end
    end

    it "is enforced below the app too (update_all / delete_all)" do
      expect { Ledger::Entry.transaction(requires_new: true) { Ledger::Entry.update_all(amount_minor: 0) } }
        .to raise_error(ActiveRecord::StatementInvalid, /UPDATE on ledger_entries refused/)
      expect { Invoice.transaction(requires_new: true) { Invoice.delete_all } }
        .to raise_error(ActiveRecord::StatementInvalid, /DELETE on invoices refused/)
      expect(booking.invoice.reload.total_minor).to eq(95_000)
    end

    it "still accepts new rows (a refund is a new reversing transaction, not an edit)" do
      before = Ledger::Entry.count
      Refunds::Create.call(payment: booking.payments.last, amount_minor: 10_000, reason: "test", auth: staff_auth(create(:user, :finance), role: "finance"))
      expect(Ledger::Entry.count).to be > before
    end

    it "lets an operator rewrite inside one transaction with the escape hatch, and only there" do
      # SET LOCAL ends with the operator's transaction (here: a rolled-back savepoint, since the
      # spec itself runs inside one).
      rewritten = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        conn.execute("SET LOCAL workerly.allow_history_rewrite = 'on'")
        rewritten = conn.update("UPDATE invoices SET total_minor = total_minor")
        raise ActiveRecord::Rollback
      end
      expect(rewritten).to eq(1)
      expect(refused?("UPDATE invoices SET total_minor = total_minor")).to be(true)
    end
  end

  describe "AppendOnly.rewriting" do
    let!(:booking) { completed_booking!(amount_minor: 95_000).tap { |b| pay_online!(b) } }

    it "allows the block, then refuses again in the same transaction" do
      ActiveRecord::Base.transaction do
        expect(AppendOnly.rewriting { conn.update("UPDATE invoices SET total_minor = total_minor") }).to eq(1)
        expect(refused?("UPDATE invoices SET total_minor = total_minor")).to be(true)
      end
    end

    it "reverts the permission when the block raises" do
      expect { AppendOnly.rewriting { raise "boom" } }.to raise_error("boom")
      expect(refused?("DELETE FROM invoices")).to be(true)
    end
  end
end
