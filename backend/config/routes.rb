Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs"
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      scope :auth, module: :auth do
        post "otp", to: "otp_requests#create"
        post "otp/verify", to: "otp_verifications#create"
        post "totp", to: "totp_verifications#create"
        post "refresh", to: "tokens#create"
        delete "session", to: "sessions#destroy"
        post "switch_role", to: "roles#create"
      end

      resource :me, only: %i[show update], controller: :me

      match "*path", to: "errors#not_found", via: :all
    end
  end
end
