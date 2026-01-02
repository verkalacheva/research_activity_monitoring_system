Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :researchers
      resources :teams
    end
  end
end

