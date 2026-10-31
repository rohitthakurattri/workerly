require "rails_helper"

RSpec.describe "Quotation lifecycle", type: :service do
  let!(:mohali) { create(:mohali) }
  let(:customer) { create(:user) }

  def accept(q, version: q.current_version) = Quotations::Accept.call(quotation: q.reload, version:, customer:, ip: "1.2.3.4", user_agent: "rspec")

  def code_of
    yield
    nil
  rescue ApplicationError => e
    e.code
  end

  describe Quotations::Create do
    it "moves the request to quoting and tells the customer's open page" do
      request, (w1, _) = matched_request(customer:)
      expect { quote!(w1, request) }.to have_broadcasted_to(RequestChannel.broadcasting_for(request)).with(hash_including(type: "quote.new"))
      expect(request.reload).to be_quoting
      expect(Quotations::CustomerQuotedJob).to have_been_enqueued
    end

    it "allows one quote per worker and at most max_quotes_per_request per request" do
      with_config(max_quotes_per_request: 2)
      request, (w1, w2, w3) = matched_request(workers: 3, customer:)
      quote!(w1, request)
      expect(code_of { quote!(w1, request) }).to eq("already_quoted")
      quote!(w2, request)
      expect(code_of { quote!(w3, request) }).to eq("quote_limit_reached")
      Quotations::Withdraw.call(quotation: w2.quotations.sole)
      expect { quote!(w3, request) }.not_to raise_error
    end

    it "refuses closed requests and declined leads" do
      request, (w1, w2) = matched_request(customer:)
      w2.invitations.sole.update!(declined_at: Time.current)
      expect(code_of { quote!(w2, request) }).to eq("lead_declined")
      travel_to(request.expires_at + 1.minute) { expect(code_of { quote!(w1, request) }).to eq("request_closed") }
    end
  end

  describe Quotations::Revise do
    it "adds an immutable revision and keeps the old one" do
      request, (w1, _) = matched_request(customer:)
      q = quote!(w1, request)
      first = q.current_revision
      Quotations::Revise.call(quotation: q, params: fixed_quote(70_000).with_indifferent_access, actor: w1.user)
      expect(q.reload.current_version).to eq(2)
      expect(q.revisions.map(&:total_minor)).to eq([ 95_000, 70_000 ])
      expect { first.update!(notes: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "can switch a quote to an inspection visit" do
      request, (w1, _) = matched_request(customer:)
      q = quote!(w1, request)
      Quotations::Revise.call(quotation: q, params: { kind: "inspection", inspection_fee_minor: 19_900 }.with_indifferent_access, actor: w1.user)
      expect(q.reload).to have_attributes(kind: "inspection")
      expect(q.current_revision.stage).to eq("inspection_fee")
    end
  end

  describe Quotations::Accept do
    it "books the request: booking, consent record, history, others declined, contact revealed" do
      request, (w1, w2) = matched_request(customer:)
      q1 = quote!(w1, request)
      q2 = quote!(w2, request, fixed_quote(60_000))

      booking = accept(q1)
      expect(booking).to have_attributes(status: "confirmed", kind: "fixed", approved_total_minor: 95_000, currency_code: "INR", worker_profile: w1)
      expect(booking.address_revealed_at).to be_present
      expect(booking.approvals.sole).to have_attributes(decision: "approved", quotation_revision: q1.current_revision, decided_by: customer, ip: IPAddr.new("1.2.3.4"))
      expect(booking.status_histories.sole).to have_attributes(from_status: nil, to_status: "confirmed", actor: customer, actor_role: "customer")
      expect(q1.reload).to be_accepted
      expect(q2.reload).to have_attributes(status: "declined", decline_reason: "another_accepted")
      expect(request.reload).to be_booked
      expect(Quotations::AcceptedJob).to have_been_enqueued.with(booking.id)
    end

    it "takes the inspection fee as the approved amount for an inspection quote" do
      request, (w1, _) = matched_request(customer:)
      q = quote!(w1, request, { kind: "inspection", inspection_fee_minor: 19_900 })
      expect(accept(q)).to have_attributes(kind: "inspection", approved_total_minor: 19_900)
    end

    it "refuses a version the customer didn't see" do
      request, (w1, _) = matched_request(customer:)
      q = quote!(w1, request)
      Quotations::Revise.call(quotation: q, params: fixed_quote(70_000).with_indifferent_access, actor: w1.user)
      expect(code_of { accept(q, version: 1) }).to eq("quotation_changed")
      expect(accept(q, version: 2).approved_total_minor).to eq(70_000)
    end

    it "refuses a second accept, expired quotes, withdrawn quotes and suspended workers" do
      request, (w1, w2, w3, w4) = matched_request(workers: 4, customer:)
      q1, q2, q3, q4 = [ w1, w2, w3, w4 ].map { |w| quote!(w, request) }

      Quotations::Withdraw.call(quotation: q3)
      expect(code_of { accept(q3) }).to eq("quotation_not_acceptable")
      w4.update!(suspended_at: Time.current, available: false)
      expect(code_of { accept(q4) }).to eq("worker_unavailable")
      q2.update_columns(valid_until: 1.minute.ago)
      expect(code_of { accept(q2) }).to eq("quotation_expired")

      accept(q1)
      expect(code_of { accept(q2) }).to eq("request_already_booked")
      expect(Booking.where(service_request: request).count).to eq(1)
    end

    it "is backed by the database: a second active booking for a request is impossible" do
      request, (w1, w2) = matched_request(customer:)
      q1 = quote!(w1, request)
      q2 = quote!(w2, request)
      accept(q1)
      expect do
        Booking.create!(service_request: request, quotation: q2, customer:, worker_profile: w2, kind: "fixed", status: "confirmed",
                        approved_total_minor: 1, currency_code: "INR", confirmed_at: Time.current)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "request closing" do
    it "expires open quotes when the customer cancels" do
      request, (w1, _) = matched_request(customer:)
      q = quote!(w1, request)
      Requests::Cancel.call(request:)
      expect(q.reload).to be_expired
    end

    it "expires open quotes with the request, and quotes past valid_until" do
      request, (w1, _) = matched_request(customer:)
      q1 = quote!(w1, request)
      other, (w3, _) = matched_request
      q3 = quote!(w3, other)
      q3.update_columns(valid_until: 1.minute.ago)

      Requests::ExpireJob.perform_now(now: request.expires_at + 1.second)
      expect(q1.reload).to be_expired
      expect(q3.reload).to be_expired
    end
  end
end
