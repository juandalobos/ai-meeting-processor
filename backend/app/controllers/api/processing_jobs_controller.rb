class Api::ProcessingJobsController < ApplicationController
  def index
    processing_jobs = ProcessingJob.includes(:meeting).order(created_at: :desc)
    render json: processing_jobs.as_json(include: :meeting)
  end
  
  def show
    processing_job = ProcessingJob.find(params[:id])
    render json: processing_job.as_json(include: :meeting)
  end
  
  def meeting_jobs
    meeting = Meeting.find(params[:meeting_id])
    processing_jobs = meeting.processing_jobs.order(created_at: :desc)
    render json: processing_jobs
  end
end
