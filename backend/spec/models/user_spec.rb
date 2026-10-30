require "rails_helper"

RSpec.describe User do
  it "allows the same phone again after soft delete, but not twice while active" do
    user = create(:user, phone_e164: "+919800000001")
    expect { described_class.new(phone_e164: user.phone_e164, public_id: SecureRandom.uuid_v7).save!(validate: false) }
      .to raise_error(ActiveRecord::RecordNotUnique)

    user.update!(deleted_at: Time.current)
    expect { create(:user, phone_e164: "+919800000001") }.not_to raise_error
  end

  it "rejects unknown roles at the database level" do
    user = create(:user)
    expect { UserRole.new(user:, role: "superuser").save!(validate: false) }
      .to raise_error(ActiveRecord::StatementInvalid, /user_roles_role_check/)
  end

  it "keeps one row per role" do
    user = create(:user)
    user.grant_role!(:customer)
    expect(user.reload.roles).to eq([ "customer" ])
  end

  it "only exposes roles that belong to the session scope" do
    user = create(:user, :worker, :admin)
    expect(user.roles_for_scope("consumer")).to contain_exactly("customer", "worker")
    expect(user.roles_for_scope("staff")).to eq([ "admin" ])
  end

  it "stores the TOTP secret encrypted" do
    user = create(:user, :admin)
    raw = described_class.connection.select_value("SELECT totp_secret FROM users WHERE id = #{user.id}")
    expect(raw).not_to include(user.totp_secret)
  end
end
