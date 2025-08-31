class TranscriptionService
  include HTTParty
  
  def initialize
    @openai_api_key = ENV['OPENAI_API_KEY']
    @aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
    @aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
    @aws_region = ENV['AWS_REGION'] || 'us-east-1'
    @google_credentials = ENV['GOOGLE_CLOUD_CREDENTIALS']
    @assembly_ai_key = ENV['ASSEMBLY_AI_KEY']
    @azure_speech_key = ENV['AZURE_SPEECH_KEY']
    @azure_speech_region = ENV['AZURE_SPEECH_REGION']
  end
  
  def transcribe_file(file)
    Rails.logger.info "=== STARTING ENHANCED TRANSCRIPTION ==="
    Rails.logger.info "File: #{file.filename}"
    Rails.logger.info "Content type: #{file.content_type}"
    Rails.logger.info "Size: #{file.byte_size} bytes"
    
    # Intentar métodos de transcripción optimizados para velocidad
    transcription_methods = [
      :extract_text_from_documents,
      :transcribe_with_openai,
      :transcribe_with_assembly_ai,
      :generate_metadata_analysis
    ]
    
    transcription_methods.each do |method|
      begin
        Rails.logger.info "Trying method: #{method}"
        result = send(method, file)
        
        if result && result.length > 50 && !result.include?('TRANSCRIPCIÓN NO DISPONIBLE')
          Rails.logger.info "Success with method: #{method}"
          return result
        end
      rescue => e
        Rails.logger.warn "Method #{method} failed: #{e.message}"
        next
      end
    end
    
    # Si todos los métodos fallan, generar análisis de metadatos
    Rails.logger.info "All transcription methods failed, generating metadata analysis"
    return generate_metadata_analysis(file)
  rescue => e
    Rails.logger.error "Transcription completely failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    return generate_fallback_message(file)
  end
  
  private
  
  def can_use_openai?
    @openai_api_key.present?
  end
  
  def can_use_assembly_ai?
    @assembly_ai_key.present?
  end
  
  def can_use_azure?
    @azure_speech_key.present? && @azure_speech_region.present?
  end
  
  def can_use_aws?
    @aws_access_key_id.present? && @aws_secret_access_key.present?
  end
  
  def can_use_google?
    @google_credentials.present?
  end
  
  def transcribe_with_openai(file)
    return nil unless can_use_openai?
    
    Rails.logger.info "Transcribing with OpenAI Whisper API"
    
    require 'openai'
    
    client = OpenAI::Client.new(access_token: @openai_api_key)
    
    # Descargar archivo temporalmente
    temp_file = download_file_to_temp(file)
    
    begin
      # Detectar idioma automáticamente
      response = client.audio.transcribe(
        parameters: {
          model: "whisper-1",
          file: File.open(temp_file.path, "rb"),
          language: "auto",
          response_format: "text",
          temperature: 0.0,
          prompt: "Esta es una reunión de trabajo. Transcribe todo el contenido de manera clara y precisa."
        }
      )
      
      if response.text && response.text.length > 50
        Rails.logger.info "OpenAI transcription successful, length: #{response.text.length}"
        return response.text
      else
        Rails.logger.warn "OpenAI transcription too short or failed"
        return nil
      end
    ensure
      # Limpiar archivo temporal
      temp_file.close
      temp_file.unlink
    end
  end
  
  def transcribe_with_assembly_ai(file)
    return nil unless can_use_assembly_ai?
    
    Rails.logger.info "Transcribing with AssemblyAI"
    
    temp_file = download_file_to_temp(file)
    
    begin
      # Subir archivo a AssemblyAI
      upload_response = HTTParty.post(
        'https://api.assemblyai.com/v2/upload',
        headers: {
          'Authorization' => @assembly_ai_key,
          'Content-Type' => 'application/octet-stream'
        },
        body: File.read(temp_file.path)
      )
      
      upload_url = JSON.parse(upload_response.body)['upload_url']
      
      # Iniciar transcripción
      transcript_response = HTTParty.post(
        'https://api.assemblyai.com/v2/transcript',
        headers: {
          'Authorization' => @assembly_ai_key,
          'Content-Type' => 'application/json'
        },
        body: {
          audio_url: upload_url,
          language_code: 'es',
          speaker_labels: true,
          auto_highlights: true,
          entity_detection: true
        }.to_json
      )
      
      transcript_id = JSON.parse(transcript_response.body)['id']
      
      # Esperar a que termine
      loop do
        status_response = HTTParty.get(
          "https://api.assemblyai.com/v2/transcript/#{transcript_id}",
          headers: { 'Authorization' => @assembly_ai_key }
        )
        
        status = JSON.parse(status_response.body)['status']
        
        if status == 'completed'
          transcript = JSON.parse(status_response.body)['text']
          Rails.logger.info "AssemblyAI transcription successful, length: #{transcript.length}"
          return transcript
        elsif status == 'error'
          raise "AssemblyAI transcription failed"
        end
        
        sleep 3
      end
    ensure
      temp_file.close
      temp_file.unlink
    end
  end
  
  def transcribe_with_azure(file)
    return nil unless can_use_azure?
    
    Rails.logger.info "Azure Speech Services not available in this version"
    Rails.logger.info "Please use OpenAI, AssemblyAI, AWS, or Google Cloud instead"
    return nil
  end
  
  def transcribe_with_aws(file)
    return nil unless can_use_aws?
    
    Rails.logger.info "Transcribing with AWS Transcribe"
    
    require 'aws-sdk-transcribeservice'
    
    # Configurar cliente AWS
    client = Aws::TranscribeService::Client.new(
      region: @aws_region,
      credentials: Aws::Credentials.new(@aws_access_key_id, @aws_secret_access_key)
    )
    
    # Generar nombre único para el job
    job_name = "transcription_#{SecureRandom.hex(8)}"
    
    # Subir archivo a S3 (requerido para AWS Transcribe)
    s3_client = Aws::S3::Client.new(
      region: @aws_region,
      credentials: Aws::Credentials.new(@aws_access_key_id, @aws_secret_access_key)
    )
    
    bucket_name = ENV['AWS_S3_BUCKET'] || 'transcription-bucket'
    s3_key = "uploads/#{job_name}/#{file.filename}"
    
    # Descargar archivo y subir a S3
    temp_file = download_file_to_temp(file)
    
    begin
      s3_client.put_object(
        bucket: bucket_name,
        key: s3_key,
        body: File.read(temp_file.path)
      )
      
      # Iniciar job de transcripción
      client.start_transcription_job(
        transcription_job_name: job_name,
        language_code: 'es-ES', # Español
        media_format: get_media_format(file.content_type),
        media: {
          media_file_uri: "s3://#{bucket_name}/#{s3_key}"
        },
        output_bucket_name: bucket_name,
        output_key: "transcriptions/#{job_name}.json"
      )
      
      # Esperar a que termine el job
      loop do
        response = client.get_transcription_job(transcription_job_name: job_name)
        status = response.transcription_job.transcription_job_status
        
        if status == 'COMPLETED'
          # Obtener resultado
          result = JSON.parse(response.transcription_job.transcript.transcript_file_uri)
          return result['results']['transcripts'][0]['transcript']
        elsif status == 'FAILED'
          raise "AWS Transcribe job failed: #{response.transcription_job.failure_reason}"
        end
        
        sleep 5
      end
    ensure
      temp_file.close
      temp_file.unlink
    end
  end
  
  def transcribe_with_google(file)
    return nil unless can_use_google?
    
    Rails.logger.info "Transcribing with Google Speech-to-Text"
    
    require 'google/cloud/speech'
    
    # Configurar cliente Google
    speech = Google::Cloud::Speech.new(
      credentials: JSON.parse(@google_credentials)
    )
    
    # Descargar archivo temporalmente
    temp_file = download_file_to_temp(file)
    
    begin
      # Leer archivo de audio
      audio_content = File.read(temp_file.path)
      
      # Configurar reconocimiento
      config = {
        encoding: :LINEAR16,
        sample_rate_hertz: 16000,
        language_code: 'es-ES',
        enable_automatic_punctuation: true,
        enable_word_time_offsets: false
      }
      
      # Realizar transcripción
      response = speech.recognize(config: config, audio: { content: audio_content })
      
      if response.results.any?
        transcript = response.results.map(&:alternatives).flatten.map(&:transcript).join(' ')
        Rails.logger.info "Google transcription successful, length: #{transcript.length}"
        return transcript
      else
        Rails.logger.warn "Google transcription returned no results"
        return nil
      end
    ensure
      temp_file.close
      temp_file.unlink
    end
  end
  
  def transcribe_with_local_processing(file)
    Rails.logger.info "Skipping local processing for speed optimization"
    return nil
  end
  
  def transcribe_with_whisper_local(file)
    Rails.logger.info "Attempting local Whisper processing"
    
    # Verificar si Whisper está instalado
    if system('which whisper > /dev/null 2>&1')
      temp_file = download_file_to_temp(file)
      
      begin
        # Usar Whisper local
        output_file = Tempfile.new(['whisper_output', '.txt'])
        
        whisper_cmd = "whisper #{temp_file.path} --language Spanish --output_dir #{File.dirname(output_file.path)} --output_format txt"
        
        if system(whisper_cmd)
          if File.exist?(output_file.path)
            transcript = File.read(output_file.path)
            Rails.logger.info "Local Whisper transcription successful, length: #{transcript.length}"
            return transcript
          end
        end
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
    
    return nil
  end
  
  def extract_text_from_documents(file)
    Rails.logger.info "Attempting document text extraction"
    
    # Para archivos de texto, PDF, etc.
    case file.content_type
    when /^text\//
      return file.read
    when /^application\/pdf/
      return extract_text_from_pdf(file)
    when /^application\/vnd\.openxmlformats-officedocument\.wordprocessingml\.document/
      return extract_text_from_docx(file)
    when /^application\/msword/
      return extract_text_from_doc(file)
    end
    
    return nil
  end
  
  def extract_text_from_pdf(file)
    require 'pdf-reader'
    
    temp_file = download_file_to_temp(file)
    
    begin
      reader = PDF::Reader.new(temp_file.path)
      text = reader.pages.map(&:text).join("\n")
      
      if text.length > 50
        Rails.logger.info "PDF text extraction successful, length: #{text.length}"
        return text
      end
    rescue => e
      Rails.logger.warn "PDF extraction failed: #{e.message}"
    ensure
      temp_file.close
      temp_file.unlink
    end
    
    return nil
  end
  
  def extract_text_from_docx(file)
    require 'docx'
    
    temp_file = download_file_to_temp(file)
    
    begin
      doc = Docx::Document.open(temp_file.path)
      text = doc.paragraphs.map(&:text).join("\n")
      
      if text.length > 50
        Rails.logger.info "DOCX text extraction successful, length: #{text.length}"
        return text
      end
    rescue => e
      Rails.logger.warn "DOCX extraction failed: #{e.message}"
    ensure
      temp_file.close
      temp_file.unlink
    end
    
    return nil
  end
  
  def extract_text_from_doc(file)
    # Para archivos .doc antiguos, intentar con antiword
    if system('which antiword > /dev/null 2>&1')
      temp_file = download_file_to_temp(file)
      
      begin
        text = `antiword "#{temp_file.path}" 2>/dev/null`
        
        if text.length > 50
          Rails.logger.info "DOC text extraction successful, length: #{text.length}"
          return text
        end
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
    
    return nil
  end
  
  def process_extracted_audio(audio_path, original_filename)
    # Análisis básico del audio extraído
    duration = get_audio_duration(audio_path)
    size = File.size(audio_path)
    
    analysis = "🎵 **ANÁLISIS DE AUDIO EXTRAÍDO**\n\n"
    analysis += "📁 **Archivo original:** #{original_filename}\n"
    analysis += "⏱️ **Duración estimada:** #{duration} segundos\n"
    analysis += "📊 **Tamaño del audio:** #{size} bytes\n"
    analysis += "🎤 **Formato:** WAV (16kHz, mono)\n\n"
    
    analysis += "✅ **Audio extraído exitosamente del video**\n\n"
    analysis += "🔧 **Para transcripción automática, configura una API key:**\n\n"
    analysis += "1. **OpenAI API** (Recomendado):\n"
    analysis += "   - Ve a https://platform.openai.com\n"
    analysis += "   - Crea una API key\n"
    analysis += "   - Agrega OPENAI_API_KEY=tu_key_aqui al archivo .env\n\n"
    analysis += "2. **AssemblyAI** (Alternativa):\n"
    analysis += "   - Ve a https://www.assemblyai.com\n"
    analysis += "   - Crea una cuenta gratuita\n"
    analysis += "   - Agrega ASSEMBLY_AI_KEY=tu_key_aqui\n\n"
    analysis += "3. **Azure Speech Services:**\n"
    analysis += "   - Configura Azure Speech\n"
    analysis += "   - Agrega AZURE_SPEECH_KEY y AZURE_SPEECH_REGION\n\n"
    analysis += "📝 **Mientras tanto, puedes:**\n"
    analysis += "• Usar Otter.ai para transcripción\n"
    analysis += "• Usar Google Docs con transcripción automática\n"
    analysis += "• Transcribir manualmente y subir como .txt"
    
    return analysis
  end
  
  def get_audio_duration(audio_path)
    if system('which ffprobe > /dev/null 2>&1')
      duration = `ffprobe -v quiet -show_entries format=duration -of csv=p=0 "#{audio_path}" 2>/dev/null`.strip
      return duration.to_f.round(2)
    end
    return "desconocida"
  end
  
  def generate_metadata_analysis(file)
    Rails.logger.info "Generating fast metadata analysis"
    
    analysis = "🔍 **ANÁLISIS RÁPIDO DEL ARCHIVO**\n\n"
    analysis += "📁 **Nombre del archivo:** #{file.filename}\n"
    analysis += "📊 **Tamaño:** #{(file.byte_size / 1024.0 / 1024.0).round(2)} MB\n"
    analysis += "🎬 **Tipo de contenido:** #{file.content_type}\n"
    analysis += "📅 **Fecha de carga:** #{Time.current.strftime('%d/%m/%Y %H:%M:%S')}\n\n"
    
    # Análisis rápido basado en el tipo de archivo
    case file.content_type
    when /^video\//
      analysis += "🎥 **ARCHIVO DE VIDEO DETECTADO**\n\n"
      analysis += "Este es un archivo de video que requiere transcripción de audio.\n"
      analysis += "Para transcripción automática, configura una API key:\n\n"
      analysis += "1. **OpenAI API** (Recomendado):\n"
      analysis += "   - Ve a https://platform.openai.com/api-keys\n"
      analysis += "   - Agrega OPENAI_API_KEY=tu_key_aqui al archivo .env\n\n"
      analysis += "2. **AssemblyAI** (Gratuito):\n"
      analysis += "   - Ve a https://www.assemblyai.com\n"
      analysis += "   - Agrega ASSEMBLY_AI_KEY=tu_key_aqui\n\n"
      analysis += "📝 **Alternativa rápida:**\n"
      analysis += "• Transcribe manualmente y sube como archivo .txt\n"
      analysis += "• Usa Otter.ai o Google Docs para transcripción\n"
      
    when /^audio\//
      analysis += "🎵 **ARCHIVO DE AUDIO DETECTADO**\n\n"
      analysis += "Este archivo puede ser transcrito directamente.\n"
      analysis += "Configura una API key para transcripción automática.\n"
      
    when /^text\//
      analysis += "📄 **ARCHIVO DE TEXTO DETECTADO**\n\n"
      analysis += "Este archivo puede ser procesado directamente.\n"
      
    else
      analysis += "❓ **TIPO DE ARCHIVO NO RECONOCIDO**\n\n"
      analysis += "Configura una API key para transcripción automática.\n"
    end
    
    return analysis
  end
  
  def download_file_to_temp(file)
    require 'tempfile'
    
    # Determinar extensión basada en content type
    extension = case file.content_type
                when /^video\//
                  '.mp4'
                when /^audio\//
                  '.mp3'
                when /^application\/pdf/
                  '.pdf'
                when /^application\/vnd\.openxmlformats-officedocument\.wordprocessingml\.document/
                  '.docx'
                when /^application\/msword/
                  '.doc'
                when /^text\//
                  '.txt'
                else
                  '.bin'
                end
    
    temp_file = Tempfile.new(['transcription', extension])
    temp_file.binmode
    
    # Descargar contenido del archivo
    file.open do |file_content|
      temp_file.write(file_content.read)
    end
    
    temp_file.rewind
    temp_file
  end
  
  def get_media_format(content_type)
    case content_type
    when /^video\/mp4/
      'mp4'
    when /^video\/avi/
      'avi'
    when /^video\/mov/
      'mov'
    when /^video\/webm/
      'webm'
    when /^audio\/mp3/
      'mp3'
    when /^audio\/wav/
      'wav'
    when /^audio\/m4a/
      'm4a'
    when /^audio\/ogg/
      'ogg'
    else
      'mp4' # Default
    end
  end
  
  def generate_fallback_message(file)
    "⚠️ **TRANSCRIPCIÓN NO DISPONIBLE**\n\n" +
    "El archivo '#{file.filename}' no pudo ser procesado automáticamente.\n\n" +
    "🔧 **CONFIGURACIÓN REQUERIDA:**\n" +
    "Para transcripción automática, configura una de estas APIs:\n\n" +
    "1. **OpenAI API** (Recomendado):\n" +
    "   - Obtén una API key en https://platform.openai.com\n" +
    "   - Agrega OPENAI_API_KEY=tu_key_aqui al archivo .env\n\n" +
    "2. **AssemblyAI** (Gratuito):\n" +
    "   - Ve a https://www.assemblyai.com\n" +
    "   - Crea una cuenta gratuita\n" +
    "   - Agrega ASSEMBLY_AI_KEY=tu_key_aqui\n\n" +
    "3. **Azure Speech Services:**\n" +
    "   - Configura Azure Speech\n" +
    "   - Agrega AZURE_SPEECH_KEY y AZURE_SPEECH_REGION\n\n" +
    "4. **AWS Transcribe:**\n" +
    "   - Configura credenciales AWS\n" +
    "   - Agrega AWS_ACCESS_KEY_ID y AWS_SECRET_ACCESS_KEY\n\n" +
    "5. **Google Speech-to-Text:**\n" +
    "   - Configura Google Cloud\n" +
    "   - Agrega GOOGLE_CLOUD_CREDENTIALS\n\n" +
    "📝 **ALTERNATIVA MANUAL:**\n" +
    "Mientras tanto, puedes:\n" +
    "• Usar Otter.ai para transcripción\n" +
    "• Usar Google Docs con transcripción automática\n" +
    "• Transcribir manualmente y subir como .txt\n" +
    "• Usar herramientas como Rev.com o Trint.com"
  end
end
