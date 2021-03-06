class FeatureChatbotConstraint
  def matches?(request)
    user = request.env["warden"].user(:user)
    if user.nil?
      Feature.chatbot_enabled?
    else
      Feature.chatbot_enabled? && user.chatbot_enabled
    end
  end
end


Rails.application.routes.draw do
  devise_for :users, controllers: {
    invitations: 'backend/invitations', registrations: 'registrations'
  }

  namespace :backend do
    resources :users, only: [:index, :destroy] do
      member do
        get :confirm_destroy
        get :reinvite
        post :toggle_quota_enabled
        post :toggle_chatbot_enabled
      end
      post :impersonate, on: :member
    end
    get 'dashboard', to: 'dashboard#index'
  end

  resource :profile, only: [:show, :edit, :update, :destroy] do
    get :confirm_destroy
    post :stop_impersonating, on: :collection
  end

  resources :chatbots, only: [:index, :show], constraints: FeatureChatbotConstraint.new do
    collection do
      get :search
    end
    member do
      get :reset
    end
    resources :chat_statements, only: [:index, :create] do
      collection do
        post :user_action
      end
    end
  end

  namespace :play do
    resource :selection, only: [:edit, :update] do
      collection do
        get :search
      end
    end
  end
  get  '/play', to: 'play#index'
  post '/play', to: 'play#interpret'
  get  '/play/reset', to: 'play#reset'

  scope '/agents' do
    resources :favorites, only: [:create, :destroy]
    resources :users, path: '', only: [] do
      resources :agents, path: '', except: [:index] do
        member do
          get :confirm_destroy
          get :confirm_transfer_ownership
          post :transfer_ownership
          post :duplicate
          get :generate_token
          get :interpret, to: 'console#interpret'
          get :full_export, to: 'agents_exports#full_export'
          get :agents_selection, to: 'agents_selection#index'
        end

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

        resources :interpretations, path: 'interpretations' do
          member do
            post :move_to_agent
          end

          get :select_new_locale
          post :add_locale
          get :confirm_destroy

          collection do
            post :update_positions
          end

          resources :aliased_interpretations, only: :index

          resources :formulations, only: [:show, :create, :edit, :update, :destroy] do
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
            get :export, to: 'entities_lists_exports#show'
          end

          get :confirm_destroy

          collection do
            post :update_positions
          end

          resources :aliased_interpretations, only: :index

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

        resources :agent_regression_checks, only: [:create, :update, :destroy] do
          collection do
            post :run
            post :update_positions
          end
        end

        resources :bots, except: [:show], constraints: FeatureChatbotConstraint.new do
          member do
            get :confirm_destroy
          end
          collection do
            get :ping
          end
        end

      end
    end
  end

  get 'agents', to: 'agents#index'

  require 'sidekiq/web'
  authenticate :user, lambda { |u| u.admin? } do
    # disable ip_spoofing, because it does not support multiple reverse proxy with different configuration (HTTP_X_REAL_IP != HTTP_X_FORWARDED_FOR)
    Sidekiq::Web.use(Rack::Protection, except: :ip_spoofing)

    mount Sidekiq::Web => '/backend/jobs'
  end

  # API with versioning
  namespace :api do
    namespace :v1 do
      scope '/agents' do
        get '/:ownername/:agentname/interpret', to: 'nlp#interpret'
      end
      get '/ping', to: 'ping#ping'
      resources 'chat_sessions', only: [:update], constraints: FeatureChatbotConstraint.new do
        resources 'statements', only: [:create], controller: 'chat_statements'
      end
    end
  end

  # API internal without versioning
  namespace :api_internal do
    get '/packages',              to: 'packages#index'
    get '/packages/:id',          to: 'packages#show'
    post '/packages/:id/updated', to: 'packages#updated'
  end

  get 'style-guide(/:page_id)', to: "style_guide#page"

  unless File.exist? File.join(Rails.root, 'public', 'index.html')
    devise_scope :user do
      unauthenticated :user do
        root 'devise/sessions#new', as: :unauthenticated_root
      end
      authenticate :user do
        root to: 'agents#index', as: :authenticated_root
      end
    end
  end

  get "connexion_state" => "application#connexion_state"

  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_error", via: :all
end
