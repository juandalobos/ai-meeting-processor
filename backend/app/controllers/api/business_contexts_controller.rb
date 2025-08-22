class Api::BusinessContextsController < ApplicationController
  def index
    business_contexts = BusinessContext.order(created_at: :desc)
    render json: business_contexts
  end
  
  def show
    business_context = BusinessContext.find(params[:id])
    render json: business_context
  end
  
  def create
    business_context = BusinessContext.new(business_context_params)
    
    if business_context.save
      render json: business_context, status: :created
    else
      render json: { errors: business_context.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def update
    business_context = BusinessContext.find(params[:id])
    
    if business_context.update(business_context_params)
      render json: business_context
    else
      render json: { errors: business_context.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def destroy
    business_context = BusinessContext.find(params[:id])
    business_context.destroy
    head :no_content
  end
  
  private
  
  def business_context_params
    params.require(:business_context).permit(:name, :content, :context_type)
  end
end
