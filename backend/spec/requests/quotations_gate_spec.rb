require "rails_helper"

# Phase 5 exit gate: two simultaneous accepts produce exactly one booking.
#
# These examples commit for real (no wrapping test transaction) so that two threads, each with
# its own database connection, race exactly as two customer taps or two tabs would in production.
RSpec.describe "Quotations exit gate", type: :request do
  self.use_transactional_tests = false

  after do
    conn = ActiveRecord::Base.connection
    conn.truncate_tables(*(conn.tables - %w[schema_migrations ar_internal_metadata]))
  end

  let!(:mohali) { create(:mohali) }
  let(:customer) { create(:user) }

  # Runs each block in its own thread and connection, released together.
  def race(*blocks)
    gate = Concurrent::CountDownLatch.new(1)
    threads = blocks.map do |block|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.wait
          block.call
        rescue ApplicationError => e
          e.code
        end
      end
    end
    gate.count_down
    threads.map(&:value)
  end

  def accept(q) = -> { Quotations::Accept.call(quotation: Quotation.find(q.id), version: 1, customer: User.find(customer.id)) }

  it "books one of two quotes accepted at the same moment, every time" do
    10.times do
      request, (w1, w2) = matched_request(customer:)
      q1 = quote!(w1, request)
      q2 = quote!(w2, request)

      results = race(accept(q1), accept(q2))

      expect(Booking.where(service_request: request).count).to eq(1)
      expect(results.count { |r| r.is_a?(Booking) }).to eq(1)
      expect(results).to include("request_already_booked")
      expect(Quotation.where(service_request: request).pluck(:status)).to contain_exactly("accepted", "declined")
      expect(request.reload).to be_booked
      request.update_columns(status: "fulfilled") # keeps the customer under the active-request limit
    end
  end

  it "books once when the same quote is accepted twice at once (double tap)" do
    request, (w1, _) = matched_request(customer:)
    q1 = quote!(w1, request)

    results = race(accept(q1), accept(q1))

    expect(Booking.where(service_request: request).count).to eq(1)
    expect(results.count { |r| r.is_a?(Booking) }).to eq(1)
    expect(results).to include("request_already_booked")
    expect(BookingApproval.count).to eq(1)
  end

  it "still books once if the row lock is missing (the unique index is the backstop)" do
    request, (w1, w2) = matched_request(customer:)
    q1 = quote!(w1, request)
    q2 = quote!(w2, request)
    allow_any_instance_of(ServiceRequest).to receive(:lock!) { |r| r.reload } # rubocop:disable RSpec/AnyInstance

    results = race(accept(q1), accept(q2))

    expect(Booking.where(service_request: request).count).to eq(1)
    expect(results.count { |r| r.is_a?(Booking) }).to eq(1)
    expect(results).to include("request_already_booked")
  end

  it "replays the stored response for a repeated Idempotency-Key over HTTP" do
    request, (w1, _) = matched_request(customer:)
    q1 = quote!(w1, request)
    headers = auth_headers_for(customer).merge("Idempotency-Key" => "accept-#{q1.public_id}")

    post("/api/v1/customer/quotations/#{q1.public_id}/accept", params: { version: 1 }.to_json, headers:)
    expect(response).to have_http_status(:created)
    first = json
    post("/api/v1/customer/quotations/#{q1.public_id}/accept", params: { version: 1 }.to_json, headers:)
    expect(response).to have_http_status(:created)
    expect(response.headers["Idempotent-Replayed"]).to eq("true")
    expect(json).to eq(first)
    expect(Booking.count).to eq(1)
  end
end
