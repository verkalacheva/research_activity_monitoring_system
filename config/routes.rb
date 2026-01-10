Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :researchers, except: [:index] do
        post :import, on: :collection
        get :list, on: :collection
      end
      resources :teams, except: [:index] do
        get :list, on: :collection
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
      resources :achievements, except: [:index] do
        post :import, on: :collection
        get :list, on: :collection
      end
    end
  end
end

