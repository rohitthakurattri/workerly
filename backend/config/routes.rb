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
          resource :voice_note, only: :create
          resources :quotations, only: :index
        end
        resources :quotations, only: :show do
          member do
            post :accept
            post :decline
          end
        end
        resources :bookings, only: %i[index show] do
          member do
            post :approvals
            post :cancel
            get :messages
            post :messages, action: :post_message
            post :review
            post :disputes
            get :invoice
          end
          resources :payments, only: :create
        end
        resources :payments, only: :show do
          post :verify, on: :member
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
          resources :quotations, only: :create
        end
        resources :quotations, only: %i[index show update] do
          post :withdraw, on: :member
        end
        resources :bookings, only: %i[index show] do
          member do
            post :schedule
            post :check_in
            post :final_quotation
            post :start
            post :change_orders
            post :complete
            post :cancel
            get :messages
            post :messages, action: :post_message
            post :cash_received
            get :invoice
          end
        end
        resources :reviews, only: :index
        resources :earnings, only: :index
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
        resources :bookings, only: %i[index show] do
          post :cancel, on: :member
        end
        resources :disputes, only: :index do
          post :resolve, on: :member
        end
        resources :payments, only: :index do
          post :refunds, on: :member, action: :refund
        end
        scope :finance, controller: :finance do
          get :balances
          post :payouts, action: :create_payout
          get :reconciliation
          get :commission_rules
          post :commission_rules, action: :create_commission_rule
        end
        get "ai/quality", to: "ai_quality#show"
        resources :audit_logs, only: :index
        resources :categories, only: %i[index create update]
      end

      post "webhooks/razorpay", to: "webhooks#razorpay"
      if Rails.env.local?
        namespace :dev do
          post "fake_payments/:order_id/capture", to: "fake_payments#capture"
        end
      end

      match "*path", to: "errors#not_found", via: :all
    end
  end
end
