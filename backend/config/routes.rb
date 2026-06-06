Rails.application.routes.draw do
  get "health/live", to: "health#live"
  get "health/ready", to: "health#ready"
  get "health", to: "health#live"

  mount ActionCable.server => '/cable'

  namespace :api do
    namespace :v1 do
      scope :auth, controller: :auth do
        post :register
        post :login
        post :refresh
        post :logout
        get :me
      end

      resources :researchers, except: [:index] do
        post :import, on: :collection
        get :list, on: :collection
        resources :dev_activities, controller: 'researcher_dev_activities', only: [:update, :destroy]
      end
      resources :teams, except: [:index] do
        get :list, on: :collection
        put :update_criteria, on: :member
      end
      resources :achievement_types, except: [:index] do
        get :list, on: :collection
      end
      resources :achievement_results, except: [:index] do
        get :list, on: :collection
      end
      resources :achievement_statuses, except: [:index] do
        get :list, on: :collection
      end
      resources :achievement_participations, except: [:index] do
        get :list, on: :collection
      end
      resources :dev_employee_activity_types, except: [:index] do
        get :list, on: :collection
      end
      resources :dev_project_criteria, except: [:index] do
        get :list, on: :collection
      end
      resources :achievements, except: [:index] do
        post :import, on: :collection
        get :list, on: :collection
      end

      resources :reports, only: [] do
        collection do
          get :selectors
          post :generate
        end
      end

      resources :integrations, only: [] do
        collection do
          post :save_achievements
        end
      end

      resources :integration_sync_jobs, only: %i[create show destroy]

      resource :settings, only: [:show, :update], controller: :settings
      resource :sync_results, only: [:show, :update, :destroy], controller: :sync_results

      scope :selectors, controller: :selectors do
        post :researchers
        post :teams
        post :achievement_statuses
        post :achievement_types
        post :achievement_results
        post :achievement_participations
        post :dev_employee_activity_types
        post :dev_project_criteria
        get  :github_check_keys
      end
    end
  end
end

