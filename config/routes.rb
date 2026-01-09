Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :researchers do
        post :import, on: :collection
      end
      resources :teams
      resources :achievement_types
      resources :achievement_results
      resources :achievement_statuses
      resources :achievement_participations
      resources :achievements do
        post :import, on: :collection
      end
    end
  end
end

