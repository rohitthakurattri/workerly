require "rails_helper"

RSpec.describe Shared::Pagination do
  it "walks every row exactly once across pages, even with equal sort keys" do
    time = Time.current.change(usec: 0)
    users = Array.new(7) { create(:user, created_at: time) }
    seen = []
    cursor = nil
    loop do
      page = described_class.call(User.all, order: { created_at: :asc, id: :asc }, cursor:, limit: 3)
      seen.concat(page.records.map(&:id))
      cursor = page.next_cursor
      break unless cursor
    end
    expect(seen).to eq(users.map(&:id))
  end

  it "caps the page size" do
    expect(described_class.new(User.all, order: { id: :asc }, limit: 1000).instance_variable_get(:@limit)).to eq(100)
  end
end
