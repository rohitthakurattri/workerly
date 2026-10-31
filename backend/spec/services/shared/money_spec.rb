require "rails_helper"

RSpec.describe Shared::Money do
  it "formats rupees with Indian grouping" do
    expect([ 0, 199_900, 1_999_950, 10_000_000, 1_234_567_800, -5_000 ].map { described_class.format(_1, "INR") })
      .to eq([ "₹0", "₹1,999", "₹19,999.50", "₹1,00,000", "₹1,23,45,678", "-₹50" ])
  end

  it "groups other currencies in thousands" do
    expect(described_class.format(123_456_789, "USD")).to eq("USD 1,234,567.89")
    expect(described_class.format(1500, "JPY")).to eq("JPY 1,500")
  end
end
