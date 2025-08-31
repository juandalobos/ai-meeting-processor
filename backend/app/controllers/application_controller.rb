class ApplicationController < ActionController::API
  def index
    render json: { status: 'OK', message: 'AI Meeting Processor API is running' }
  end
end
