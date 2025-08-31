require 'httparty'
require 'ostruct'

class VideoProcessorService
  include HTTParty

  def initialize
    @openai_api_key = ENV['OPENAI_API_KEY']
    @gemini_api_key = ENV['GEMINI_API_KEY']
    @ffmpeg_available = check_ffmpeg_availability
  end

  def process_video(video_file, job_type, language = 'es')
    Rails.logger.info "=== STARTING VIDEO PROCESSING ==="
    Rails.logger.info "Video file: #{video_file.filename}"
    Rails.logger.info "Job type: #{job_type}"
    Rails.logger.info "Language: #{language}"
    Rails.logger.info "FFmpeg available: #{@ffmpeg_available}"

    begin
      # Paso 1: Extraer audio del video
      audio_file = extract_audio_from_video(video_file)

      if audio_file.nil?
        Rails.logger.error "Failed to extract audio from video"
        return generate_fallback_message(video_file, "No se pudo extraer audio del video")
      end

      # Paso 2: Transcribir el audio
      transcription = transcribe_audio(audio_file)

      if transcription.nil? || transcription.length < 50
        Rails.logger.error "Failed to transcribe audio or transcription too short"
        return generate_fallback_message(video_file, "No se pudo transcribir el audio del video")
      end

      Rails.logger.info "Transcription successful, length: #{transcription.length}"

      # Paso 3: Procesar con Gemini
      gemini_service = GeminiService.new
      result = gemini_service.process_meeting_content_from_text(transcription, job_type, language)

      Rails.logger.info "Video processing completed successfully"
      return result

    rescue => e
      Rails.logger.error "Video processing failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return generate_fallback_message(video_file, "Error procesando video: #{e.message}")
    ensure
      # Limpiar archivos temporales
      cleanup_temp_files
    end
  end

  private

  def check_ffmpeg_availability
    system('which ffmpeg > /dev/null 2>&1')
  end

  def extract_audio_from_video(video_file)
    return nil unless @ffmpeg_available
    
    Rails.logger.info "Extracting audio from video using FFmpeg"
    
    # Crear archivo temporal para el audio
    temp_audio = Tempfile.new(['audio', '.wav'])
    temp_video = download_file_to_temp(video_file)
    
    begin
      # Comando FFmpeg simplificado y más robusto
      cmd = "ffmpeg -i \"#{temp_video.path}\" -vn -acodec pcm_s16le -ar 16000 -ac 1 \"#{temp_audio.path}\" -y"
      
      Rails.logger.info "Running FFmpeg command: #{cmd}"
      
      # Ejecutar comando sin timeout para debugging
      result = system(cmd)
      
      Rails.logger.info "FFmpeg result: #{result}"
      Rails.logger.info "Audio file exists: #{File.exist?(temp_audio.path)}"
      Rails.logger.info "Audio file size: #{File.size(temp_audio.path) if File.exist?(temp_audio.path)}"
      
      if result && File.exist?(temp_audio.path) && File.size(temp_audio.path) > 1000
        Rails.logger.info "Audio extraction successful"
        return temp_audio
      else
        Rails.logger.error "Audio extraction failed - result: #{result}, file exists: #{File.exist?(temp_audio.path)}, size: #{File.size(temp_audio.path) if File.exist?(temp_audio.path)}"
        return nil
      end
    rescue => e
      Rails.logger.error "Error extracting audio: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return nil
    end
  end

  def transcribe_audio(audio_file)
    Rails.logger.info "Transcribing audio with TranscriptionService"

    # Usar TranscriptionService que tiene múltiples opciones
    transcription_service = TranscriptionService.new
    
    # Crear un mock del archivo para TranscriptionService
    mock_file = OpenStruct.new(
      filename: 'audio.wav',
      content_type: 'audio/wav',
      byte_size: File.size(audio_file.path),
      download: -> { File.read(audio_file.path) }
    )
    
    begin
      result = transcription_service.transcribe_file(mock_file)
      
      if result && result.length > 50
        Rails.logger.info "Transcription successful, length: #{result.length}"
        return result
      else
        Rails.logger.warn "Transcription too short or failed"
        return nil
      end
    rescue => e
      Rails.logger.error "Transcription error: #{e.message}"
      return nil
    end
  end

  def download_file_to_temp(file)
    temp_file = Tempfile.new(['video', File.extname(file.filename.to_s)])
    temp_file.binmode
    temp_file.write(file.download)
    temp_file.rewind
    temp_file
  end

  def cleanup_temp_files
    # Los archivos temporales se limpian automáticamente cuando se cierran
    # pero podemos forzar la limpieza si es necesario
  end

  def generate_fallback_message(video_file, reason)
    <<~FALLBACK
      **PROCESAMIENTO DE VIDEO NO DISPONIBLE**

      **Archivo:** #{video_file.filename}
      **Tamaño:** #{video_file.byte_size} bytes
      **Tipo:** #{video_file.content_type}

      **Razón:** #{reason}

      **Soluciones:**
      1. Asegúrate de que FFmpeg esté instalado en el sistema
      2. Verifica que la clave de API de OpenAI esté configurada
      3. El video debe contener audio para poder procesarlo
      4. Intenta con un archivo de audio directamente

      **Configuración requerida:**
      - FFmpeg instalado en el sistema
      - OPENAI_API_KEY configurada en las variables de entorno

      Para instalar FFmpeg:
      - macOS: `brew install ffmpeg`
      - Ubuntu: `sudo apt-get install ffmpeg`
      - Windows: Descargar desde https://ffmpeg.org/
    FALLBACK
  end
end
OS DE 