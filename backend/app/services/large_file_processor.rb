class LargeFileProcessor
  include HTTParty
  
  MAX_FILE_SIZE = 100.megabytes
  MAX_CHUNK_SIZE = 25.megabytes
  MAX_TEXT_LENGTH = 100_000 # 100k caracteres
  
  def initialize
    @openai_api_key = ENV['OPENAI_API_KEY']
    @gemini_api_key = ENV['GEMINI_API_KEY']
  end
  
  def process_large_file(file, meeting)
    Rails.logger.info "=== PROCESSING LARGE FILE ==="
    Rails.logger.info "File: #{file.filename}"
    Rails.logger.info "Size: #{file.byte_size} bytes"
    Rails.logger.info "Content type: #{file.content_type}"
    
    # Determinar el tipo de archivo
    if video_file?(file)
      process_large_video(file, meeting)
    elsif text_file?(file)
      process_large_text(file, meeting)
    elsif document_file?(file)
      process_large_document(file, meeting)
    else
      process_unknown_file(file, meeting)
    end
  end
  
  private
  
  def video_file?(file)
    content_type = file.content_type.downcase
    %w[video/mp4 video/avi video/mov video/wmv video/flv video/webm video/mkv].include?(content_type)
  end
  
  def text_file?(file)
    content_type = file.content_type.downcase
    %w[text/plain text/csv text/html].include?(content_type)
  end
  
  def document_file?(file)
    content_type = file.content_type.downcase
    %w[application/pdf application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document].include?(content_type)
  end
  
  def process_large_video(file, meeting)
    Rails.logger.info "Processing large video file"
    
    # Verificar tamaño del archivo
    if file.byte_size > MAX_FILE_SIZE
      return handle_oversized_file(file, meeting)
    end
    
    # Obtener duración del video para decidir el método de procesamiento
    temp_file = download_file_to_temp(file)
    duration = get_video_duration(temp_file.path)
    temp_file.close
    temp_file.unlink
    
    # Para videos cortos (< 10 minutos), procesar directamente
    # Para videos largos, usar chunks
    if duration && duration > 600 # 10 minutos
      return process_video_in_chunks(file, meeting)
    else
      return process_video_directly(file, meeting)
    end
  end
  
  def process_large_text(file, meeting)
    Rails.logger.info "Processing large text file"
    
    # Extraer contenido del texto
    content = extract_text_content(file)
    
    if content.length > MAX_TEXT_LENGTH
      return process_text_in_chunks(content, meeting)
    else
      return process_text_directly(content, meeting)
    end
  end
  
  def process_large_document(file, meeting)
    Rails.logger.info "Processing large document file"
    
    # Extraer texto del documento
    content = extract_document_content(file)
    
    if content.length > MAX_TEXT_LENGTH
      return process_text_in_chunks(content, meeting)
    else
      return process_text_directly(content, meeting)
    end
  end
  
  def process_unknown_file(file, meeting)
    Rails.logger.info "Processing unknown file type"
    
    # Intentar extraer cualquier texto disponible
    content = extract_any_content(file)
    
    if content && content.length > 0
      return process_text_directly(content, meeting)
    else
      return generate_unsupported_file_message(file, meeting)
    end
  end
  
  def process_video_in_chunks(file, meeting)
    Rails.logger.info "Processing video in chunks"
    
    # Crear chunks del video usando ffmpeg
    chunks = create_video_chunks(file)
    
    if chunks.empty?
      return generate_video_processing_error(file, meeting)
    end
    
    # Transcribir cada chunk
    transcriptions = []
    chunks.each_with_index do |chunk_path, index|
      Rails.logger.info "Processing chunk #{index + 1}/#{chunks.length}"
      
      transcription = transcribe_video_chunk(chunk_path)
      if transcription
        transcriptions << transcription
      end
      
      # Limpiar chunk temporal
      File.delete(chunk_path) if File.exist?(chunk_path)
    end
    
    # Combinar transcripciones
    combined_transcription = transcriptions.join("\n\n")
    
    if combined_transcription.length > 0
      return process_text_directly(combined_transcription, meeting)
    else
      return generate_transcription_error(file, meeting)
    end
  end
  
  def process_video_directly(file, meeting)
    Rails.logger.info "Processing video directly"
    
    # Usar el servicio de transcripción existente
    transcription_service = TranscriptionService.new
    transcription = transcription_service.transcribe_file(file)
    
    if transcription && transcription.length > 50
      return process_text_directly(transcription, meeting)
    else
      return generate_transcription_error(file, meeting)
    end
  end
  
  def process_text_in_chunks(content, meeting)
    Rails.logger.info "Processing text in chunks"
    
    # Dividir contenido en chunks
    chunks = split_text_into_chunks(content)
    
    # Procesar cada chunk
    summaries = []
    chunks.each_with_index do |chunk, index|
      Rails.logger.info "Processing text chunk #{index + 1}/#{chunks.length}"
      
      summary = process_text_chunk(chunk, index + 1, chunks.length)
      if summary
        summaries << summary
      end
    end
    
    # Combinar resúmenes
    combined_summary = combine_summaries(summaries)
    
    return {
      success: true,
      content: combined_summary,
      chunks_processed: chunks.length,
      total_length: content.length
    }
  end
  
  def process_text_directly(content, meeting)
    Rails.logger.info "Processing text directly"
    
    # Usar el servicio Gemini existente
    gemini_service = GeminiService.new
    result = gemini_service.build_executive_summary_prompt(content)
    
    return {
      success: true,
      content: result,
      total_length: content.length
    }
  end
  
  def create_video_chunks(file)
    Rails.logger.info "Creating video chunks"
    
    temp_file = download_file_to_temp(file)
    chunks = []
    
    begin
      # Obtener duración del video
      duration = get_video_duration(temp_file.path)
      
      if duration.nil?
        Rails.logger.error "Could not determine video duration"
        return []
      end
      
      # Crear chunks de 10 minutos cada uno
      chunk_duration = 600 # 10 minutos en segundos
      chunk_count = (duration / chunk_duration.to_f).ceil
      
      Rails.logger.info "Video duration: #{duration} seconds, creating #{chunk_count} chunks"
      
      chunk_count.times do |i|
        start_time = i * chunk_duration
        end_time = [(i + 1) * chunk_duration, duration].min
        
        chunk_path = create_video_chunk(temp_file.path, start_time, end_time, i)
        chunks << chunk_path if chunk_path
      end
      
    ensure
      temp_file.close
      temp_file.unlink
    end
    
    chunks
  end
  
  def get_video_duration(file_path)
    require 'streamio-ffmpeg'
    
    begin
      movie = FFMPEG::Movie.new(file_path)
      return movie.duration
    rescue => e
      Rails.logger.error "Error getting video duration: #{e.message}"
      return nil
    end
  end
  
  def create_video_chunk(input_path, start_time, end_time, index)
    require 'streamio-ffmpeg'
    
    output_path = "/tmp/video_chunk_#{index}_#{SecureRandom.hex(4)}.mp4"
    
    begin
      movie = FFMPEG::Movie.new(input_path)
      options = { custom: "-ss #{start_time} -t #{end_time - start_time} -c copy" }
      movie.transcode(output_path, options)
      
      if File.exist?(output_path) && File.size(output_path) > 0
        return output_path
      else
        return nil
      end
    rescue => e
      Rails.logger.error "Error creating video chunk: #{e.message}"
      return nil
    end
  end
  
  def transcribe_video_chunk(chunk_path)
    return nil unless can_use_openai?
    
    require 'openai'
    
    client = OpenAI::Client.new(access_token: @openai_api_key)
    
    begin
      response = client.audio.transcribe(
        parameters: {
          model: "whisper-1",
          file: File.open(chunk_path, "rb"),
          language: "auto",
          response_format: "text",
          temperature: 0.0
        }
      )
      
      return response.text if response.text && response.text.length > 10
      return nil
    rescue => e
      Rails.logger.error "Error transcribing chunk: #{e.message}"
      return nil
    end
  end
  
  def split_text_into_chunks(content)
    # Dividir por párrafos o líneas
    paragraphs = content.split(/\n\s*\n/)
    
    chunks = []
    current_chunk = ""
    
    paragraphs.each do |paragraph|
      if (current_chunk + paragraph).length > MAX_TEXT_LENGTH
        if current_chunk.length > 0
          chunks << current_chunk.strip
          current_chunk = paragraph
        else
          # Párrafo individual muy largo, dividirlo
          chunks.concat(split_long_paragraph(paragraph))
        end
      else
        current_chunk += "\n\n" + paragraph
      end
    end
    
    chunks << current_chunk.strip if current_chunk.length > 0
    chunks
  end
  
  def split_long_paragraph(paragraph)
    # Dividir párrafos muy largos por oraciones
    sentences = paragraph.split(/[.!?]+/)
    chunks = []
    current_chunk = ""
    
    sentences.each do |sentence|
      if (current_chunk + sentence).length > MAX_TEXT_LENGTH
        if current_chunk.length > 0
          chunks << current_chunk.strip
          current_chunk = sentence
        else
          # Oración individual muy larga, dividir por palabras
          chunks.concat(split_long_sentence(sentence))
        end
      else
        current_chunk += sentence + ". "
      end
    end
    
    chunks << current_chunk.strip if current_chunk.length > 0
    chunks
  end
  
  def split_long_sentence(sentence)
    # Dividir oraciones muy largas por palabras
    words = sentence.split(/\s+/)
    chunks = []
    current_chunk = ""
    
    words.each do |word|
      if (current_chunk + " " + word).length > MAX_TEXT_LENGTH
        if current_chunk.length > 0
          chunks << current_chunk.strip
          current_chunk = word
        else
          # Palabra individual muy larga, truncar
          chunks << word[0...MAX_TEXT_LENGTH]
        end
      else
        current_chunk += " " + word
      end
    end
    
    chunks << current_chunk.strip if current_chunk.length > 0
    chunks
  end
  
  def process_text_chunk(chunk, chunk_index, total_chunks)
    return nil unless can_use_gemini?
    
    require 'google/apis/generative_ai_v1beta'
    
    client = Google::Apis::GenerativeAiV1beta::GenerativeAiService.new
    client.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(@gemini_api_key)
    )
    
    prompt = "Analiza este fragmento #{chunk_index} de #{total_chunks} de una reunión y genera un resumen ejecutivo conciso:\n\n#{chunk}"
    
    begin
      response = client.generate_content(
        model: "gemini-1.5-flash",
        contents: [{ parts: [{ text: prompt }] }]
      )
      
      return response.candidates.first.content.parts.first.text
    rescue => e
      Rails.logger.error "Error processing text chunk: #{e.message}"
      return nil
    end
  end
  
  def combine_summaries(summaries)
    return "No se pudieron procesar los fragmentos del archivo." if summaries.empty?
    
    if summaries.length == 1
      return summaries.first
    end
    
    # Combinar resúmenes usando Gemini
    combined_text = summaries.join("\n\n---\n\n")
    prompt = "Combina estos resúmenes de fragmentos de una reunión en un resumen ejecutivo coherente y completo:\n\n#{combined_text}"
    
    return process_text_chunk(prompt, 1, 1) || combined_text
  end
  
  def extract_text_content(file)
    temp_file = download_file_to_temp(file)
    
    begin
      return File.read(temp_file.path, encoding: 'UTF-8')
    rescue => e
      Rails.logger.error "Error reading text file: #{e.message}"
      return ""
    ensure
      temp_file.close
      temp_file.unlink
    end
  end
  
  def extract_document_content(file)
    temp_file = download_file_to_temp(file)
    
    begin
      if file.content_type.include?('pdf')
        require 'pdf-reader'
        reader = PDF::Reader.new(temp_file.path)
        return reader.pages.map(&:text).join("\n")
      elsif file.content_type.include?('word')
        require 'docx'
        doc = Docx::Document.open(temp_file.path)
        return doc.paragraphs.map(&:text).join("\n")
      else
        return File.read(temp_file.path, encoding: 'UTF-8')
      end
    rescue => e
      Rails.logger.error "Error reading document: #{e.message}"
      return ""
    ensure
      temp_file.close
      temp_file.unlink
    end
  end
  
  def extract_any_content(file)
    # Intentar extraer cualquier contenido disponible
    begin
      return extract_text_content(file)
    rescue
      begin
        return extract_document_content(file)
      rescue
        return nil
      end
    end
  end
  
  def download_file_to_temp(file)
    temp_file = Tempfile.new(['large_file', File.extname(file.filename.to_s)])
    temp_file.binmode
    temp_file.write(file.download)
    temp_file.rewind
    temp_file
  end
  
  def can_use_openai?
    @openai_api_key.present?
  end
  
  def can_use_gemini?
    @gemini_api_key.present?
  end
  
  def handle_oversized_file(file, meeting)
    {
      success: false,
      error: "Archivo demasiado grande",
      message: "El archivo excede el tamaño máximo permitido de #{MAX_FILE_SIZE / 1.megabyte}MB. Por favor, divide el archivo en partes más pequeñas o comprime el video."
    }
  end
  
  def generate_video_processing_error(file, meeting)
    {
      success: false,
      error: "Error procesando video",
      message: "No se pudo procesar el archivo de video. Verifica que el archivo tenga audio y esté en un formato soportado."
    }
  end
  
  def generate_transcription_error(file, meeting)
    {
      success: false,
      error: "Error de transcripción",
      message: "No se pudo transcribir el contenido del archivo. Verifica que el archivo tenga audio claro y esté en un formato soportado."
    }
  end
  
  def generate_unsupported_file_message(file, meeting)
    {
      success: false,
      error: "Tipo de archivo no soportado",
      message: "El tipo de archivo no es compatible. Usa archivos de video, audio, texto o documentos (PDF, DOCX)."
    }
  end
end
