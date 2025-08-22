Rails.application.routes.draw do
  # Health check endpoint for Railway
  get '/api/health', to: proc { [200, {}, ['OK']] }
  
  # API routes
  namespace :api do
    resources :meetings do
      member do
        post :process_content
      end
    end
    
    resources :business_contexts
    resources :processing_jobs, only: [:index, :show]
  end
  
  # Root route
  root 'application#index'
end
