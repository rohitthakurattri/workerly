namespace :admin do
  desc 'Grant a staff role and provision TOTP: bin/rails "admin:grant[+919876543210,admin]"'
  task :grant, %i[phone role] => :environment do |_, args|
    role = args[:role].presence || "admin"
    abort "Role must be one of #{User::STAFF_ROLES.join(', ')}" unless User::STAFF_ROLES.include?(role)
    phone = Identity::PhoneNumber.normalize!(args[:phone])

    user = User.kept.find_or_create_by!(phone_e164: phone)
    user.grant_role!(:customer)
    user.grant_role!(role)
    puts "#{phone} now has roles: #{user.reload.roles.sort.join(', ')}"

    if user.totp_enabled? && ENV["RESET_TOTP"] != "1"
      puts "TOTP already set up (run with RESET_TOTP=1 to replace it)."
    else
      uri = Identity::Totp.provision!(user)
      puts "Add this to an authenticator app (shown once):\n  #{uri}"
    end
  end

  desc 'Revoke a staff role: bin/rails "admin:revoke[+919876543210,admin]"'
  task :revoke, %i[phone role] => :environment do |_, args|
    user = User.kept.find_by!(phone_e164: Identity::PhoneNumber.normalize!(args[:phone]))
    user.user_roles.where(role: args[:role]).destroy_all
    user.user_sessions.where(scope: "staff", revoked_at: nil).find_each { |s| s.revoke!("role_revoked") } unless user.staff?
    puts "Roles: #{user.reload.roles.sort.join(', ')}"
  end
end
