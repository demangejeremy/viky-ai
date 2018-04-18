Rails.application.routes.draw do
  devise_for :users, controllers: {
    invitations: 'backend/invitations', registrations: 'registrations'
  }

  namespace :backend do
    resources :users, only: [:index, :destroy] do
      member do
        get :confirm_destroy
        get :reinvite
      end
      post :impersonate, on: :member
    end
  end

  resource :profile, only: [:show, :edit, :update, :destroy] do
    get :confirm_destroy
    post :stop_impersonating, on: :collection
  end

  resources :chatbots, only: [:index, :show] do
    member do
      get :reset
    end
    resources :chat_statements, only: [:create]
  end

  scope '/agents' do
    resources :favorites, only: [:create, :destroy]
    resources :users, path: '', only: [] do
      resources :agents, path: '', except: [:index] do
        member do
          get :confirm_destroy
          get :confirm_transfer_ownership
          post :transfer_ownership
          get :search_users_for_transfer_ownership
          get :generate_token
          get :interpret, to: 'console#interpret'
          get :full_export
          get :agents_selection, to: 'agents_selection#index'
        end
        get :search_users_to_share_agent, controller: 'memberships'

        resources :memberships, only: [:index, :new, :create, :update, :destroy] do
          get :confirm_destroy
        end

        resources :dependencies, only: [:new, :create, :destroy] do
          get :confirm_destroy
          collection do
            get :successors_graph
            get :predecessors_graph
          end
        end

        resource :readme, except: [:show] do
          get :confirm_destroy
        end

        resources :intents, path: 'interpretations' do
          member do
            post :move_to_agent
          end
          get :select_new_locale
          post :add_locale
          delete :remove_locale
          get :confirm_destroy
          collection do
            post :update_positions
          end

          resources :interpretations, only: [:show, :create, :edit, :update, :destroy] do
            member do
              get :show_detailed
              post :update_locale
            end
            collection do
              post :update_positions
            end
          end
        end

        resources :entities_lists do
          member do
            post :move_to_agent
          end
          get :confirm_destroy
          collection do
            post :update_positions
          end

          resources :entities, only: [:show, :create, :edit, :update, :destroy] do
            member do
              get :show_detailed
            end
            collection do
              post :update_positions
              get :new_import
              post :create_import
            end
          end
        end

        resources :bots, except: [:show] do
          member do
            get :confirm_destroy
          end
        end
      end
    end
  end

  get 'agents', to: 'agents#index'

  require 'sidekiq/web'
  authenticate :user, lambda { |u| u.admin? } do

    # disable ip_spoofing, because it does not support multiple reverse proxy with different configuration (HTTP_X_REAL_IP != HTTP_X_FORWARDED_FOR)
    Sidekiq::Web.use( Rack::Protection, except: :ip_spoofing)

    mount Sidekiq::Web => '/backend/jobs'
  end

  # API with versioning
  namespace :api do
    namespace :v1 do
      scope '/agents' do
        get '/:ownername/:agentname/interpret', to: 'nlp#interpret'
      end
      scope '/chat_sessions/:id' do
        resources 'statements', only: [:create]
      end
    end
  end

  # API internal without versioning
  namespace :api_internal do
      get '/packages',     to: 'packages#index'
      get '/packages/:id', to: 'packages#show'
  end

  get 'style-guide', to: 'style_guide#index'
  get 'style-guide/:page_id', to: "style_guide#page"

  get 'brain', to: 'brain#index'

  unauthenticated :user do
    root to: "marketing#index", as: :unauthenticated_root
  end

  authenticate :user do
    root to: 'agents#index', as: :authenticated_root
  end

  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_error", via: :all
end
