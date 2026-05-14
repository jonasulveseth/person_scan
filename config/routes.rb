Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :users, only: %i[new create]
  get  "signup",      to: "users#new",       as: :signup
  get  "login",       to: "sessions#new",    as: :login
  get  "splash",      to: "landing#splash",  as: :splash
  get  "how-it-works", to: "landing#how_it_works", as: :how_it_works

  resources :sites, param: :id do
    resources :visitors, only: :show do
      post :reclassify, on: :member
      post :save_as_training_example, to: "training_examples#save_from_visitor", on: :member
    end
    resources :api_keys, only: %i[index create destroy] do
      post :revoke, on: :member
    end
    get :trends, on: :member
  end

  resources :model_configs do
    post :make_default, on: :member
  end

  resources :training_examples do
    collection do
      post :import_legacy
      post :import_csv
    end
  end

  resources :evaluation_runs, only: %i[index show create]

  namespace :api do
    namespace :v1 do
      get  "site",                       to: "site#show"
      get  "visitors",                   to: "visitors#index"
      get  "visitors/:fingerprint",      to: "visitors#show", constraints: { fingerprint: /[^\/]+/ }
    end
  end

  # Root: landing for visitors, dashboard for authenticated users
  root "landing#splash"

  scope module: :ingest, defaults: { format: :json } do
    match "visitor/new-session", to: "visitors#new_session", via: [:post, :options]
    match "visitor/track",       to: "visitors#track",       via: [:post, :options]
    match "link_clicks",         to: "link_clicks#link_click", via: [:post, :options]
    match "page_visits",         to: "page_visits#page_visit", via: [:post, :options]
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
