Rails.application.routes.draw do
  namespace :api do
    resources :meetings do
      member do
        post :process_content
        post :translate_result
      end
    end
    
    resources :business_contexts
    
    resources :processing_jobs, only: [:index, :show] do
      collection do
        get :meeting_jobs
      end
    end
  end
  
  get "up" => "rails/health#show", as: :rails_health_check
end
