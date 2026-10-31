require "rails_helper"

RSpec.describe "Live leads (Action Cable)", type: :channel do
  let!(:mohali) { create(:mohali) }
  let(:worker) { create(:worker_profile, :matchable) }

  def ticket_for(user, role:, scope: "consumer")
    session = Identity::Sessions.start(user:, scope:, role:, mfa: scope == "staff").session
    Identity::Tokens.cable_ticket(session:, role:)
  end

  describe ApplicationCable::Connection, type: :channel do
    it "connects with a valid ticket" do
      connect params: { ticket: ticket_for(worker.user, role: "worker") }
      expect(connection.current_user).to eq(worker.user)
      expect(connection.current_role).to eq("worker")
    end

    it "rejects missing, forged and expired tickets" do
      expect { connect params: {} }.to have_rejected_connection
      expect { connect params: { ticket: "nope" } }.to have_rejected_connection
      ticket = ticket_for(worker.user, role: "worker")
      travel(2.minutes) { expect { connect params: { ticket: } }.to have_rejected_connection }
    end

    it "rejects a ticket used twice" do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      ticket = ticket_for(worker.user, role: "worker")
      connect(params: { ticket: })
      expect { connect params: { ticket: } }.to have_rejected_connection
    end

    it "rejects tickets for sessions that have ended" do
      ticket = ticket_for(worker.user, role: "worker")
      UserSession.update_all(revoked_at: Time.current)
      expect { connect params: { ticket: } }.to have_rejected_connection
    end
  end

  describe WorkerLeadsChannel, type: :channel do
    it "streams leads to approved workers" do
      stub_connection current_user: worker.user, current_role: "worker", session_id: "s"
      subscribe
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_for(worker)
    end

    it "rejects unverified or suspended workers and other roles" do
      pending_worker = create(:worker_profile, :pending_review)
      stub_connection current_user: pending_worker.user, current_role: "worker", session_id: "s"
      subscribe
      expect(subscription).to be_rejected

      worker.update!(available: false, suspended_at: Time.current)
      stub_connection current_user: worker.user, current_role: "worker", session_id: "s"
      subscribe
      expect(subscription).to be_rejected

      stub_connection current_user: worker.user, current_role: "customer", session_id: "s"
      subscribe
      expect(subscription).to be_rejected
    end
  end
end
