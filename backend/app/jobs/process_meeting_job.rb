class ProcessMeetingJob < ApplicationJob
  queue_as :default
  
  def perform(meeting_id, job_type, language = 'es')
    meeting = Meeting.find(meeting_id)
    processing_job = meeting.processing_jobs.find_or_create_by(job_type: job_type)
    
    begin
      processing_job.update(status: 'processing')
      
      # Detectar si es un video y usar el procesador específico
      if meeting.file.attached? && video_file?(meeting.file)
        Rails.logger.info "Processing video file with VideoProcessorService"
        video_processor = VideoProcessorService.new
        result = video_processor.process_video(meeting.file, job_type, language)
      else
        # Procesamiento normal para otros tipos de archivo
        gemini_service = GeminiService.new
        result = gemini_service.process_meeting_content(meeting, job_type, nil, language)
      end
      
      processing_job.update(
        status: 'completed',
        result: result
      )
      
      meeting.update(status: 'completed') if meeting.processing_jobs.all?(&:completed?)
      
    rescue => e
      # Determinar el tipo de error y proporcionar mensaje específico
      error_message = case
      when e.message.include?('overloaded')
        "Error: La API de Gemini está temporalmente sobrecargada. El sistema reintentará automáticamente. Si el problema persiste, intenta nuevamente en unos minutos."
      when e.message.include?('timeout')
        "Error: La solicitud tardó demasiado en procesarse. Esto puede deberse a contenido muy largo o problemas de conectividad. Intenta con contenido más corto."
      when e.message.include?('video') || e.message.include?('audio')
        "Error: Los archivos de video y audio requieren transcripción previa. Por favor, proporciona una transcripción en formato texto (.txt) del contenido."
      when e.message.include?('PDF')
        "Error: El archivo PDF no contiene texto extraíble. Por favor, convierte el PDF a texto o proporciona una transcripción."
      when e.message.include?('API')
        "Error de la API: #{e.message}. Por favor, verifica que el contenido sea válido e intenta nuevamente."
      else
        "Error inesperado: #{e.message}. Por favor, intenta nuevamente o contacta al administrador si el problema persiste."
      end
      
      processing_job.update(
        status: 'failed',
        result: error_message
      )
      
      meeting.update(status: 'failed')
      
      Rails.logger.error "Processing job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
  
  private
  
  def video_file?(file)
    video_types = [
      'video/mp4',
      'video/avi',
      'video/mov',
      'video/wmv',
      'video/flv',
      'video/webm',
      'video/mkv',
      'video/m4v'
    ]
    video_types.include?(file.content_type)
  end
end
