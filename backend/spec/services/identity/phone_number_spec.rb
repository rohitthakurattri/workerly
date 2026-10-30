require "rails_helper"

RSpec.describe Identity::PhoneNumber do
  {
    "9876543210" => "+919876543210",
    "98765 43210" => "+919876543210",
    "098765-43210" => "+919876543210",
    "+91 98765 43210" => "+919876543210",
    "919876543210" => "+919876543210",
    "0091 9876543210" => "+919876543210"
  }.each do |input, expected|
    it("normalises #{input.inspect}") { expect(described_class.normalize(input)).to eq(expected) }
  end

  [ "", nil, "12345", "5876543210", "+1 415 555 0100", "98765432101", "abcdefghij" ].each do |input|
    it("rejects #{input.inspect}") { expect(described_class.normalize(input)).to be_nil }
  end

  it "masks all but the last four digits" do
    expect(described_class.mask("+919876543210")).to eq("+91******3210")
  end
end
