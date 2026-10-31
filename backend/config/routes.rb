Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs"
  end

  # Action Cable is mounted at /cable (config.action_cable.mount_path).

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

      resources :categories, only: %i[index show], param: :slug
      resources :cable_tickets, only: :create
      resources :devices, only: :create do
        collection do
          get :push_config
          delete "", action: :destroy
        end
      end
      resources :notifications, only: :index do
        post :read, on: :member
        post :read_all, on: :collection
      end
      resources :cities, only: :index

      namespace :customer do
        resources :addresses, only: %i[index create update destroy]
        resources :service_requests, only: %i[index show create update destroy] do
          member do
            post :submit
            post :cancel
          end
          resource :triage, only: :create
          resources :attachments, only: %i[create destroy]
        end
      end

      namespace :worker do
        resource :registration, only: :create
        resource :profile, only: %i[show update] do
          post :submit_for_review, action: :submit
        end
        resource :verification, only: :show
        resource :skills, only: :update
        resource :availability, only: :update
        resources :service_areas, only: %i[index create update destroy]
        resources :documents, only: %i[index create destroy]
        resources :leads, only: %i[index show] do
          post :decline, on: :member
        end
      end

      namespace :admin do
        resources :workers, only: %i[index show] do
          member do
            post :verification, action: :verify
            post :suspend
            post :reinstate
          end
        end
        resources :service_requests, only: %i[index show]
        resources :audit_logs, only: :index
        resources :categories, only: %i[index create update]
      end

      match "*path", to: "errors#not_found", via: :all
    end
  end
end
