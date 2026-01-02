Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :researchers
      resources :teams
      resources :achievement_types
      resources :achievement_results
      resources :achievement_statuses
    end
  end
end

