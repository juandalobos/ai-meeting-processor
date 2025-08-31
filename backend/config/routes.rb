Rails.application.routes.draw do
  # Health check endpoint for Railway
  get '/api/health', to: proc { [200, {}, ['OK']] }
  
  # API routes
  namespace :api do
    resources :meetings do
      member do
        post :process_content
        get :processing_status
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
  
  # Root route
  root 'application#index'
end
