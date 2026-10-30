FactoryBot.define do
  factory :user do
    sequence(:phone_e164) { |n| "+9198#{format('%08d', n)}" }
    name { Faker::Name.name }

    after(:create) { |user| user.grant_role!(:customer) }

    trait :worker do
      after(:create) { |user| user.grant_role!(:worker) }
    end

    trait :suspended do
      status { "suspended" }
    end

    trait :admin do
      after(:create) do |user|
        user.grant_role!(:admin)
        Identity::Totp.provision!(user)
      end
    end

    trait :finance do
      after(:create) do |user|
        user.grant_role!(:finance)
        Identity::Totp.provision!(user) unless user.totp_enabled?
      end
    end
  end
end
