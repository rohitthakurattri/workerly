require "rails_helper"

RSpec.describe Ledger::Post do
  let(:worker) { create(:worker_profile) }
  let(:clearing) { Ledger::Account.for(:gateway_clearing, currency_code: "INR") }
  let(:payable) { Ledger::Account.for(:worker_payable, currency_code: "INR", owner: worker) }
  let(:revenue) { Ledger::Account.for(:platform_revenue, currency_code: "INR") }
  let(:entries) do
    [ { account: clearing, direction: "debit", amount_minor: 100_000 },
      { account: payable, direction: "credit", amount_minor: 90_000 },
      { account: revenue, direction: "credit", amount_minor: 10_000 } ]
  end

  it "posts a balanced transaction and keeps balances" do
    tx = described_class.call(kind: "job_payment", idempotency_key: "payment:1:captured", entries:)
    expect(tx.entries.count).to eq(3)
    expect([ clearing, payable, revenue ].map(&:balance_minor)).to eq([ 100_000, -90_000, -10_000 ])
    expect(Ledger::Entry.sum(Arel.sql("CASE direction WHEN 'debit' THEN amount_minor ELSE -amount_minor END"))).to eq(0)
  end

  it "is idempotent per key and refuses a different body under the same key" do
    first = described_class.call(kind: "job_payment", idempotency_key: "k1", entries:)
    expect(described_class.call(kind: "job_payment", idempotency_key: "k1", entries:)).to eq(first)
    expect(Ledger::Transaction.count).to eq(1)
    changed = entries.dup.tap { |e| e[0] = e[0].merge(amount_minor: 1) }
    expect { described_class.call(kind: "job_payment", idempotency_key: "k1", entries: changed) }.to raise_error(described_class::KeyReused)
  end

  it "refuses unbalanced or non-positive entries" do
    expect { described_class.call(kind: "x", idempotency_key: "k2", entries: entries.first(2)) }.to raise_error(described_class::Unbalanced)
    expect { described_class.call(kind: "x", idempotency_key: "k3", entries: [ entries[0].merge(amount_minor: 0), entries[1] ]) }
      .to raise_error(described_class::Unbalanced)
    expect(Ledger::Transaction.count).to eq(0)
  end

  it "never changes or deletes entries" do
    tx = described_class.call(kind: "job_payment", idempotency_key: "k4", entries:)
    expect { tx.entries.first.update!(amount_minor: 1) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { tx.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "has one account per owner, kind and currency" do
    expect(Ledger::Account.for(:gateway_clearing, currency_code: "INR")).to eq(clearing)
    expect(Ledger::Account.for(:worker_payable, currency_code: "INR", owner: worker)).to eq(payable)
  end
end
