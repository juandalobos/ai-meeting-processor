class ProcessLargeFileJob < ApplicationJob
  queue_as :default
  
  def perform(meeting_id, job_type, language = 'es')
    Rails.logger.info "=== STARTING LARGE FILE PROCESSING JOB ==="
    Rails.logger.info "Meeting ID: #{meeting_id}"
    Rails.logger.info "Job Type: #{job_type}"
    Rails.logger.info "Language: #{language}"
    
    meeting = Meeting.find(meeting_id)
    
    unless meeting.file.attached?
      Rails.logger.error "No file attached to meeting #{meeting_id}"
      return
    end
    
    # Actualizar estado del meeting
    meeting.update(status: 'processing')
    
    begin
      # Procesar archivo grande
      large_file_processor = LargeFileProcessor.new
      result = large_file_processor.process_large_file(meeting.file, meeting)
      
      if result[:success]
        # Procesar el contenido extraído con Gemini
        gemini_service = GeminiService.new
        processed_result = gemini_service.process_meeting_content(meeting, job_type, result[:content], language)
        
        # Guardar resultado
        processing_job = meeting.processing_jobs.find_or_create_by(job_type: job_type)
        processing_job.update(status: 'completed', result: processed_result)
        
        # Actualizar estado del meeting
        meeting.update(status: 'completed')
        
        Rails.logger.info "Large file processing completed successfully"
        Rails.logger.info "Chunks processed: #{result[:chunks_processed]}"
        Rails.logger.info "Total length: #{result[:total_length]}"
      else
        # Manejar error
        processing_job = meeting.processing_jobs.find_or_create_by(job_type: job_type)
        processing_job.update(status: 'failed', result: result[:message])
        
        meeting.update(status: 'failed')
        
        Rails.logger.error "Large file processing failed: #{result[:error]}"
        Rails.logger.error "Message: #{result[:message]}"
      end
      
    rescue => e
      Rails.logger.error "Large file processing job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Actualizar estado del meeting
      meeting.update(status: 'failed')
      
      # Guardar error en processing job
      processing_job = meeting.processing_jobs.find_or_create_by(job_type: job_type)
      processing_job.update(status: 'failed', result: "Error: #{e.message}")
    end
  end
end
