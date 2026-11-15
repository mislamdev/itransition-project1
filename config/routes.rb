Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  # --- authentication, registration and settings (QA) ---
  get    "sign_up"  => "registrations#new",   as: :sign_up
  post   "sign_up"  => "registrations#create"
  get    "sign_in"  => "sessions#new",        as: :sign_in
  post   "sign_in"  => "sessions#create"
  delete "sign_out" => "sessions#destroy",    as: :sign_out

  # OmniAuth callback. The request phase (/auth/:provider) is handled by the
  # OmniAuth middleware itself and needs no application route.
  match  "auth/:provider/callback" => "omniauth#callback", via: [:get, :post], as: :omniauth_callback
  get    "auth/failure" => "omniauth#failure"

  # Personal settings (language, theme) and password change.
  match  "settings" => "settings#update", via: [:post, :patch, :put], as: :settings
  patch  "settings/password" => "settings#update_password", as: :settings_password

  namespace :admin do
    resources :users, only: [:index, :update, :destroy]
  end

  # ---------------------------------------------------------------------------
  # Public pages (backend)
  # ---------------------------------------------------------------------------
  root "dashboard#index"
  get "dashboard" => "dashboard#index", as: :dashboard
  get "search" => "search#index", as: :search

  # ---------------------------------------------------------------------------
  # Inventories (backend)
  # ---------------------------------------------------------------------------
  resources :inventories do
    # Tab: items
    resources :items, only: [:index, :new, :create]

    # Tab: discussion
    resources :comments, only: [:index, :create]

    # Tab: custom fields
    resources :fields, controller: "inventory_fields", only: [:index, :new, :create, :edit, :update, :destroy] do
      collection do
        post :reorder
      end
    end

    # Tab: access management
    resources :accesses, controller: "inventory_accesses", only: [:index, :create, :destroy] do
      collection do
        get :suggestions
      end
    end

    # Tab: custom inventory numbers
    resource :custom_id, controller: "inventory_custom_ids", only: [:edit, :update] do
      member do
        match :preview, via: [:get, :post]
      end
    end

    # Tab: statistics
    get :statistics, on: :member
  end

  # Items are addressed globally as well, so that an item can be linked to
  # from anywhere (search results, the discussion, ...).
  resources :items, only: [:show, :edit, :update, :destroy] do
    resource :like, only: [:create, :destroy]
  end

  # Personal pages
  resources :users, only: [:show]
  get "profile" => "users#profile", as: :profile

  # Switches an inventory between public and private (the switch of the
  # access tab).
  patch "inventories/:inventory_id/accesses" => "inventory_accesses#update", as: :update_inventory_accesses

  # ---------------------------------------------------------------------------
  # JSON API (backend)
  # ---------------------------------------------------------------------------
  namespace :api do
    get "search" => "search#index"
    get "suggestions/users" => "suggestions#users"
    get "suggestions/tags" => "suggestions#tags"
  end
end
