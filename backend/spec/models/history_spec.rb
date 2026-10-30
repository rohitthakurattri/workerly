require "rails_helper"

RSpec.describe "Append-only history", type: :model do
  let(:admin) { create(:user, :admin) }

  it "never updates or deletes verification and audit rows" do
    profile = create(:worker_profile)
    v = WorkerVerification.create!(worker_profile: profile, admin:, decision: "suspended", reason: "x")
    expect { v.update!(reason: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { v.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)

    a = AdminAction.create!(admin:, admin_role: "admin", action: "x", target_type: "User", target_id: 1)
    expect { a.update!(reason: "y") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "keeps one live document per kind at the database level" do
    profile = create(:worker_profile)
    create(:worker_document, worker_profile: profile, kind: "identity")
    dup = build(:worker_document, worker_profile: profile, kind: "identity", public_id: SecureRandom.uuid_v7)
    expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "refuses audit entries without a staff session" do
    expect { Admin::Audit.record!(action: "x", target: admin, auth: nil) }.to raise_error(ArgumentError)
  end
end
