class Api::MeetingsController < ApplicationController
  def index
    meetings = Meeting.order(created_at: :desc)
    render json: meetings.as_json(include: :processing_jobs)
  end
  
  def show
    meeting = Meeting.find(params[:id])
    render json: meeting.as_json(include: :processing_jobs)
  end
  
  def create
    meeting = Meeting.new(meeting_params)
    meeting.status = 'pending'
    
    # Si no se proporciona título, usar el nombre del archivo
    if meeting.title.blank? && meeting.file.attached?
      meeting.title = meeting.file.filename.to_s
    elsif meeting.title.blank?
      meeting.title = 'Reunión sin título'
    end
    
    if meeting.save
      render json: meeting.as_json(include: :processing_jobs), status: :created
    else
      Rails.logger.error "Meeting creation failed: #{meeting.errors.full_messages}"
      render json: { 
        errors: meeting.errors.full_messages,
        details: meeting.errors.details
      }, status: :unprocessable_entity
    end
  end
  
  def process_content
    meeting = Meeting.find(params[:id])
    job_type = params[:job_type]
    language = params[:language] || 'es'
    
    unless %w[proposal jira_ticket executive_summary].include?(job_type)
      return render json: { error: 'Tipo de trabajo inválido' }, status: :bad_request
    end
    
    unless %w[en es].include?(language)
      return render json: { error: 'Idioma inválido' }, status: :bad_request
    end
    
    # Para videos, usar procesamiento específico de video
    if meeting.file.attached? && video_file?(meeting.file)
      Rails.logger.info "Video detected, using video processing"
      ProcessMeetingJob.perform_later(meeting.id, job_type, language)
      render json: { 
        message: 'Procesamiento de video iniciado', 
        job_type: job_type,
        file_size: meeting.file.byte_size,
        file_type: 'video',
        estimated_time: '1-3 minutos'
      }
    # Para archivos grandes (no videos), usar procesamiento de archivos grandes
    elsif meeting.file.attached? && meeting.file.byte_size > 5.megabytes
      Rails.logger.info "Large file detected, using large file processing"
      ProcessLargeFileJob.perform_later(meeting.id, job_type, language)
      render json: { 
        message: 'Procesamiento de archivo grande iniciado', 
        job_type: job_type,
        file_size: meeting.file.byte_size,
        estimated_time: '2-5 minutos'
      }
    elsif Rails.env.development? && params[:sync] == 'true'
      # Solo para archivos pequeños en desarrollo
      begin
        gemini_service = GeminiService.new
        result = gemini_service.process_meeting_content(meeting, job_type, nil, language)
        
        processing_job = meeting.processing_jobs.find_or_create_by(job_type: job_type)
        processing_job.update(status: 'completed', result: result)
        
        render json: { message: 'Procesamiento completado', job_type: job_type, result: result }
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end
    else
      # Usar job específico para archivos grandes
      if meeting.file.attached? && meeting.file.byte_size > 10.megabytes
        ProcessLargeFileJob.perform_later(meeting.id, job_type, language)
        render json: { 
          message: 'Procesamiento de archivo grande iniciado', 
          job_type: job_type,
          file_size: meeting.file.byte_size,
          estimated_time: '5-15 minutos'
        }
      else
        ProcessMeetingJob.perform_later(meeting.id, job_type, language)
        render json: { message: 'Procesamiento iniciado', job_type: job_type }
      end
    end
  end

  def translate_result
    meeting = Meeting.find(params[:id])
    job_type = params[:job_type]
    target_language = params[:language]

    unless %w[en es].include?(target_language)
      return render json: { error: 'Idioma inválido' }, status: :bad_request
    end

    # Buscar el job existente
    processing_job = meeting.processing_jobs.find_by(job_type: job_type)
    
    unless processing_job&.result
      return render json: { error: 'No hay resultado para traducir' }, status: :not_found
    end

    begin
      gemini_service = GeminiService.new
      translated_result = gemini_service.translate_content(processing_job.result, target_language)
      
      # Actualizar el resultado con la traducción
      processing_job.update(result: translated_result)
      
      render json: { 
        message: 'Traducción completada', 
        job_type: job_type, 
        result: translated_result,
        language: target_language
      }
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  def processing_status
    meeting = Meeting.find(params[:id])
    
    render json: {
      meeting_id: meeting.id,
      status: meeting.status,
      file_size: meeting.file.attached? ? meeting.file.byte_size : nil,
      is_large_file: meeting.file.attached? && meeting.file.byte_size > 10.megabytes,
      processing_jobs: meeting.processing_jobs.map do |job|
        {
          job_type: job.job_type,
          status: job.status,
          created_at: job.created_at,
          updated_at: job.updated_at,
          has_result: job.result.present?
        }
      end
    }
  end
  
  private
  
  def meeting_params
    params.require(:meeting).permit(:title, :file)
  end
  
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
