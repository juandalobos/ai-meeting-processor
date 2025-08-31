


class GeminiService
  include HTTParty
  
  base_uri 'https://generativelanguage.googleapis.com/v1beta'
  
  def initialize(api_key = nil)
    @api_key = api_key || 'AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0'
    @model = 'gemini-1.5-flash'
  end
  
  def process_meeting_content(meeting, job_type, business_context = nil, language = 'es')
    Rails.logger.info "=== STARTING PROCESSING ==="
    
    content = extract_meeting_content(meeting)
    
    if content.include?('No se ha proporcionado') || 
       content.include?('no contiene contenido procesable') ||
       content.include?('no es compatible actualmente')
      return content
    end
    
    if content.length > 200000
      Rails.logger.info "Content very long (#{content.length} chars), truncating to 200000 chars"
      content = content[0...200000] + "\n\n[CONTENIDO TRUNCADO - Se procesó solo la primera parte para mayor velocidad.]"
    end
    
    context = build_context(business_context)
    prompt = build_prompt(content, job_type, context, language)
  
    Rails.logger.info "Starting Gemini API call..."
    
    begin
      response = generate_content(prompt)
      
      if response['candidates']&.first&.dig('content', 'parts', 0, 'text')
        result = response['candidates'].first['content']['parts'][0]['text']
        Rails.logger.info "Processing completed successfully"
        result
      else
        raise "Error processing content: #{response['error']&.dig('message') || 'Unknown error'}"
      end
    rescue => e
      Rails.logger.warn "Gemini API failed, using fallback processing: #{e.message}"
      
      fallback_result = process_with_fallback(content, job_type, language)
      
      fallback_result + "\n\n" +
      "⚠️ NOTA: Este resultado fue generado en modo básico debido a problemas con la API de IA.\n" +
      "Para obtener resultados más detallados, intenta nuevamente en unos minutos."
    end
  end

  def process_meeting_content_from_text(text_content, job_type, language = 'es')
    Rails.logger.info "=== STARTING TEXT PROCESSING ==="
    Rails.logger.info "Text length: #{text_content.length}"
    
    if text_content.length > 200000
      Rails.logger.info "Content very long (#{text_content.length} chars), truncating to 200000 chars"
      text_content = text_content[0...200000] + "\n\n[CONTENIDO TRUNCADO - Se procesó solo la primera parte para mayor velocidad.]"
    end
    
    prompt = build_prompt(text_content, job_type, nil, language)
  
    Rails.logger.info "Starting Gemini API call..."
    
    begin
      response = generate_content(prompt)
      
      if response['candidates']&.first&.dig('content', 'parts', 0, 'text')
        result = response['candidates'].first['content']['parts'][0]['text']
        Rails.logger.info "Text processing completed successfully"
        result
      else
        raise "Error processing text content: #{response['error']&.dig('message') || 'Unknown error'}"
      end
    rescue => e
      Rails.logger.warn "Gemini API failed, using fallback processing: #{e.message}"
      
      fallback_result = process_with_fallback(text_content, job_type, language)
      
      fallback_result + "\n\n" +
      "⚠️ NOTA: Este resultado fue generado en modo básico debido a problemas con la API de IA.\n" +
      "Para obtener resultados más detallados, intenta nuevamente en unos minutos."
    end
  end

  def translate_content(content, target_language)
    Rails.logger.info "=== STARTING TRANSLATION ==="
    Rails.logger.info "Target language: #{target_language}"
    Rails.logger.info "Content length: #{content.length}"
    
    # Determinar el idioma de origen
    source_language = detect_language(content)
    Rails.logger.info "Detected source language: #{source_language}"
    
    # Si ya está en el idioma objetivo, no traducir
    if source_language == target_language
      Rails.logger.info "Content already in target language, no translation needed"
      return content
    end
    
    # Crear prompt de traducción
    translation_prompt = build_translation_prompt(content, source_language, target_language)
    
    Rails.logger.info "Starting translation with Gemini API..."
    
    begin
      response = generate_content(translation_prompt)
      
      if response['candidates']&.first&.dig('content', 'parts', 0, 'text')
        result = response['candidates'].first['content']['parts'][0]['text']
        Rails.logger.info "Translation completed successfully"
        result
      else
        raise "Error translating content: #{response['error']&.dig('message') || 'Unknown error'}"
      end
    rescue => e
      Rails.logger.warn "Translation failed: #{e.message}"
      raise "Error de traducción: #{e.message}"
    end
  end

  def build_executive_summary_prompt(content, context = nil, language = 'es')
    prompt = case language
    when 'es'
      <<~PROMPT
        Analiza el siguiente contenido de una reunión y genera un resumen ejecutivo completo y detallado.
        
        CONTEXTO DEL NEGOCIO:
        #{context || 'No se proporcionó contexto específico del negocio.'}
        
        CONTENIDO DE LA REUNIÓN:
        #{content}
        
        INSTRUCCIONES ESPECÍFICAS:
        1. SOLO usa información REAL y EXPLÍCITA del contenido proporcionado
        2. NO inventes, infieras o agregues información que no esté presente
        3. Si falta información, indícalo claramente
        4. Estructura el resumen en las siguientes secciones:
        
        **RESUMEN EJECUTIVO**
        [Resumen general de 2-3 párrafos]
        
        **PUNTOS CLAVE DISCUTIDOS**
        [Lista de los temas principales]
        
        **ACCIONABLES PRIORITARIOS**
        [Tareas específicas con responsables y fechas si están disponibles]
        
        **RESPONSABLES Y ASIGNACIONES**
        [Personas mencionadas y sus roles/tareas]
        
        **PRÓXIMOS PASOS Y CRONOGRAMA**
        [Planes futuros y fechas mencionadas]
        
        **DECISIONES TOMADAS**
        [Decisiones específicas mencionadas]
        
        **RIESGOS Y CONSIDERACIONES**
        [Riesgos o preocupaciones mencionadas]
        
        IMPORTANTE: Si alguna sección no tiene información suficiente, escribe "No hay información suficiente en el contenido proporcionado para [sección]."
      PROMPT
    when 'en'
      <<~PROMPT
        Analyze the following meeting content and generate a comprehensive and detailed executive summary.
        
        BUSINESS CONTEXT:
        #{context || 'No specific business context provided.'}
        
        MEETING CONTENT:
        #{content}
        
        SPECIFIC INSTRUCTIONS:
        1. ONLY use REAL and EXPLICIT information from the provided content
        2. DO NOT invent, infer, or add information that is not present
        3. If information is missing, indicate it clearly
        4. Structure the summary in the following sections:
        
        **EXECUTIVE SUMMARY**
        [General summary of 2-3 paragraphs]
        
        **KEY POINTS DISCUSSED**
        [List of main topics]
        
        **PRIORITY ACTION ITEMS**
        [Specific tasks with assignees and dates if available]
        
        **RESPONSIBILITIES AND ASSIGNMENTS**
        [People mentioned and their roles/tasks]
        
        **NEXT STEPS AND TIMELINE**
        [Future plans and mentioned dates]
        
        **DECISIONS MADE**
        [Specific decisions mentioned]
        
        **RISKS AND CONSIDERATIONS**
        [Risks or concerns mentioned]
        
        IMPORTANT: If any section doesn't have sufficient information, write "There is insufficient information in the provided content for [section]."
      PROMPT
    else
      raise "Unsupported language: #{language}"
    end
    
    prompt
  end

  private
  
  def extract_meeting_content(meeting)
    Rails.logger.info "=== EXTRACTING MEETING CONTENT ==="
    Rails.logger.info "Meeting ID: #{meeting.id}"
    Rails.logger.info "Meeting Title: #{meeting.title}"
    Rails.logger.info "File attached: #{meeting.file.attached?}"
    
    if meeting.file.attached?
      Rails.logger.info "File name: #{meeting.file.filename}"
      Rails.logger.info "File content type: #{meeting.file.content_type}"
      file_content = extract_file_content(meeting.file)
      Rails.logger.info "Extracted file content length: #{file_content&.length || 0}"
      
      if file_content.present?
        return file_content
      else
        return generate_no_content_message(meeting.file.content_type, 'es')
      end
    else
      return "No se ha proporcionado ningún archivo para procesar."
    end
  end

  def extract_file_content(file)
    Rails.logger.info "=== EXTRACTING FILE CONTENT ==="
    Rails.logger.info "File: #{file.filename}"
    Rails.logger.info "Content type: #{file.content_type}"
    Rails.logger.info "Size: #{file.byte_size} bytes"
    
    case file.content_type
    when /^text\//
      extract_text_content(file)
    when /^application\/pdf/
      extract_pdf_content(file)
    when /^application\/.*word/
      extract_word_content(file)
    when /^video\//
      extract_video_content(file)
    when /^audio\//
      extract_audio_content(file)
    else
      generate_unsupported_format_message(file.content_type, 'es')
    end
  end

  def extract_text_content(file)
    Rails.logger.info "Extracting text content"
    begin
      content = file.download.force_encoding('UTF-8')
      Rails.logger.info "Text content extracted successfully, length: #{content.length}"
      content
    rescue => e
      Rails.logger.error "Error extracting text content: #{e.message}"
      "Error al extraer el contenido del archivo de texto: #{e.message}"
    end
  end

  def extract_pdf_content(file)
    Rails.logger.info "Extracting PDF content"
    begin
      require 'pdf-reader'
      content = ""
      file.open do |f|
        reader = PDF::Reader.new(f)
        reader.pages.each do |page|
          content += page.text + "\n"
        end
      end
      Rails.logger.info "PDF content extracted successfully, length: #{content.length}"
      content
    rescue => e
      Rails.logger.error "Error extracting PDF content: #{e.message}"
      "Error al extraer el contenido del PDF: #{e.message}"
    end
  end

  def extract_word_content(file)
    Rails.logger.info "Extracting Word content"
    begin
      require 'docx'
      content = ""
      file.open do |f|
        doc = Docx::Document.open(f.path)
        doc.paragraphs.each do |paragraph|
          content += paragraph.text + "\n"
        end
      end
      Rails.logger.info "Word content extracted successfully, length: #{content.length}"
      content
    rescue => e
      Rails.logger.error "Error extracting Word content: #{e.message}"
      "Error al extraer el contenido del documento Word: #{e.message}"
    end
  end

  def extract_video_content(file)
    Rails.logger.info "Extracting video content"
    begin
      transcription_service = TranscriptionService.new
      result = transcription_service.transcribe_file(file)
      
      if result
        Rails.logger.info "Video transcription completed, length: #{result.length}"
        return result
      else
        Rails.logger.warn "Video transcription failed, using fallback"
        return generate_video_fallback_message('es')
      end
    rescue => e
      Rails.logger.error "Error extracting video content: #{e.message}"
      generate_video_fallback_message('es')
    end
  end

  def extract_audio_content(file)
    Rails.logger.info "Extracting audio content"
    begin
      transcription_service = TranscriptionService.new
      result = transcription_service.transcribe_file(file)
      
      if result
        Rails.logger.info "Audio transcription completed, length: #{result.length}"
        return result
      else
        Rails.logger.warn "Audio transcription failed, using fallback"
        return generate_audio_fallback_message('es')
      end
    rescue => e
      Rails.logger.error "Error extracting audio content: #{e.message}"
      generate_audio_fallback_message('es')
    end
  end

  def build_context(business_context)
    if business_context
      "Contexto del negocio: #{business_context.description}"
    else
      "No se proporcionó contexto específico del negocio."
    end
  end

  def build_prompt(content, job_type, context, language)
    case job_type
    when 'executive_summary'
      build_executive_summary_prompt(content, context, language)
    when 'jira_ticket'
      build_jira_ticket_prompt(content, context, language)
    when 'proposal', 'technical_proposal'
      build_technical_proposal_prompt(content, context, language)
    else
      raise "Unsupported job type: #{job_type}"
    end
  end

  def build_jira_ticket_prompt(content, context, language)
    if language == 'es'
      <<~PROMPT
        Analiza el siguiente contenido de una reunión y genera tickets de Jira estructurados.
        
        CONTEXTO DEL NEGOCIO:
        #{context}
        
        CONTENIDO DE LA REUNIÓN:
        #{content}
        
        INSTRUCCIONES:
        1. Identifica todas las tareas, problemas y acciones mencionadas
        2. Genera tickets de Jira para cada elemento identificado
        3. Usa SOLO información real del contenido
        4. NO inventes información que no esté presente
        
        ESTRUCTURA REQUERIDA:
        
        **Épica: [Nombre de la Épica]**
        Problema: [Descripción del problema principal]
        Solución: [Descripción de la solución propuesta]
        Contexto: [Contexto adicional]
        
        **Historia de Usuario: [Nombre de la Historia]**
        Prioridad: [Alta/Media/Baja]
        Problema: [Descripción específica del problema]
        Solución: [Descripción de la solución]
        Criterios de Aceptación:
        - [Criterio 1]
        - [Criterio 2]
        Estimación: [Tiempo estimado]
        
        **Tarea Técnica: [Nombre de la Tarea]**
        Prioridad: [Alta/Media/Baja]
        Problema: [Descripción técnica del problema]
        Solución: [Descripción técnica de la solución]
        Tiempo: [Estimación]
        Dependencias: [Dependencias identificadas]
        
        IMPORTANTE: Si no hay información suficiente, indícalo claramente.
      PROMPT
    else
      <<~PROMPT
        Analyze the following meeting content and generate structured Jira tickets.
        
        BUSINESS CONTEXT:
        #{context}
        
        MEETING CONTENT:
        #{content}
        
        INSTRUCTIONS:
        1. Identify all tasks, issues and actions mentioned
        2. Generate Jira tickets for each identified item
        3. Use ONLY real information from the content
        4. DO NOT invent information that is not present
        
        REQUIRED STRUCTURE:
        
        **Epic: [Epic Name]**
        Problem: [Description of the main problem]
        Solution: [Description of the proposed solution]
        Context: [Additional context]
        
        **User Story: [Story Name]**
        Priority: [High/Medium/Low]
        Problem: [Specific problem description]
        Solution: [Solution description]
        Acceptance Criteria:
        - [Criterion 1]
        - [Criterion 2]
        Estimation: [Estimated time]
        
        **Technical Task: [Task Name]**
        Priority: [High/Medium/Low]
        Problem: [Technical problem description]
        Solution: [Technical solution description]
        Time: [Estimation]
        Dependencies: [Identified dependencies]
        
        IMPORTANT: If there is insufficient information, indicate it clearly.
      PROMPT
    end
  end

  def build_technical_proposal_prompt(content, context, language)
    if language == 'es'
      <<~PROMPT
        Analiza el siguiente contenido de una reunión y genera una propuesta técnica siguiendo el formato empresarial estándar.
        
        CONTEXTO DEL NEGOCIO:
        #{context}
        
        CONTENIDO DE LA REUNIÓN:
        #{content}
        
        INSTRUCCIONES:
        1. Identifica el problema principal y la solución propuesta
        2. Genera una propuesta siguiendo el formato empresarial estándar
        3. Usa SOLO información real del contenido
        4. NO inventes información que no esté presente
        5. Sé conciso y usa viñetas cuando sea apropiado
        
        ESTRUCTURA REQUERIDA:
        
        **TL;DR**
        [Resumen ejecutivo del problema y solución en 2 párrafos máximo (100 palabras)]
        
        **Problem**
        [Descripción clara del problema que se está resolviendo]
        
        **What's not covered by this proposal?**
        [Puntos que NO están cubiertos por esta propuesta]
        
        **Product Spec**
        [Especificación del producto/solución propuesta]
        
        **Stakeholders**
        [Lista de stakeholders clave identificados en la reunión]
        
        **User Stories**
        [Historias de usuario basadas en el contenido de la reunión]
        
        **Proposed Solution**
        [Descripción de la solución propuesta]
        
        **Target value (result)**
        [Valor objetivo y resultados esperados]
        
        **Existing Solutions**
        [Soluciones existentes mencionadas o identificadas]
        
        **KPIs**
        [Métricas de éxito y cómo medir el éxito]
        
        **Risks & Mitigation**
        [Riesgos identificados y sus mitigaciones]
        
        **Tech Spec**
        [Especificaciones técnicas si están disponibles]
        
        **Tasks**
        [Tareas identificadas con estimaciones de tiempo]
        
        IMPORTANTE: 
        - Si alguna sección no tiene información suficiente, indícalo claramente
        - Mantén el documento conciso y enfocado
        - Usa viñetas y formato claro
        - Prioriza la información más importante
      PROMPT
    else
      <<~PROMPT
        Analyze the following meeting content and generate a technical proposal following the standard business format.
        
        BUSINESS CONTEXT:
        #{context}
        
        MEETING CONTENT:
        #{content}
        
        INSTRUCTIONS:
        1. Identify the main problem and proposed solution
        2. Generate a proposal following the standard business format
        3. Use ONLY real information from the content
        4. DO NOT invent information that is not present
        5. Be concise and use bullet points when appropriate
        
        REQUIRED STRUCTURE:
        
        **TL;DR**
        [Executive summary of the problem and solution in maximum 2 paragraphs (100 words)]
        
        **Problem**
        [Clear description of the problem being solved]
        
        **What's not covered by this proposal?**
        [Points NOT covered by this proposal]
        
        **Product Spec**
        [Product/solution specification]
        
        **Stakeholders**
        [List of key stakeholders identified in the meeting]
        
        **User Stories**
        [User stories based on meeting content]
        
        **Proposed Solution**
        [Description of the proposed solution]
        
        **Target value (result)**
        [Target value and expected results]
        
        **Existing Solutions**
        [Existing solutions mentioned or identified]
        
        **KPIs**
        [Success metrics and how to measure success]
        
        **Risks & Mitigation**
        [Identified risks and their mitigations]
        
        **Tech Spec**
        [Technical specifications if available]
        
        **Tasks**
        [Identified tasks with time estimates]
        
        IMPORTANT: 
        - If any section doesn't have sufficient information, indicate it clearly
        - Keep the document concise and focused
        - Use bullet points and clear formatting
        - Prioritize the most important information
      PROMPT
    end
  end

  def generate_content(prompt)
    Rails.logger.info "Generating content with Gemini API"
    
    response = self.class.post("/models/#{@model}:generateContent?key=#{@api_key}", {
      headers: {
        'Content-Type' => 'application/json'
      },
      body: {
        contents: [{
          parts: [{
            text: prompt
          }]
        }]
      }.to_json
    })
    
    Rails.logger.info "Gemini API response status: #{response.code}"
    
    if response.success?
      JSON.parse(response.body)
    else
      Rails.logger.error "Gemini API error: #{response.code} - #{response.body}"
      raise "Gemini API error: #{response.code}"
    end
  end

  def process_with_fallback(content, job_type, language)
    Rails.logger.info "Processing with fallback method"
    
    case job_type
    when 'executive_summary'
      generate_fallback_summary(content, language)
    when 'jira_ticket'
      generate_fallback_jira_tickets(content, language)
    when 'proposal', 'technical_proposal'
      generate_fallback_proposal(content, language)
    else
      "Tipo de trabajo no soportado: #{job_type}"
    end
  end

  def generate_fallback_summary(content, language)
    if language == 'es'
      "**RESUMEN EJECUTIVO (MODO BÁSICO)**\n\n" +
      "El contenido proporcionado contiene: #{content.length} caracteres.\n\n" +
      "**PUNTOS CLAVE DISCUTIDOS**\n" +
      "No hay información suficiente en el contenido proporcionado para generar un resumen ejecutivo completo.\n\n" +
      "**ACCIONABLES PRIORITARIOS**\n" +
      "No hay información suficiente en el contenido proporcionado para identificar acciones prioritarias.\n\n" +
      "**RESPONSABLES Y ASIGNACIONES**\n" +
      "No hay información suficiente en el contenido proporcionado para identificar responsables.\n\n" +
      "**PRÓXIMOS PASOS Y CRONOGRAMA**\n" +
      "No hay información suficiente en el contenido proporcionado para detallar próximos pasos.\n\n" +
      "**DECISIONES TOMADAS**\n" +
      "No hay información suficiente en el contenido proporcionado para listar decisiones.\n\n" +
      "**RIESGOS Y CONSIDERACIONES**\n" +
      "No hay información suficiente en el contenido proporcionado para identificar riesgos."
    else
      "**EXECUTIVE SUMMARY (BASIC MODE)**\n\n" +
      "The provided content contains: #{content.length} characters.\n\n" +
      "**KEY POINTS DISCUSSED**\n" +
      "There is insufficient information in the provided content to generate a complete executive summary.\n\n" +
      "**PRIORITY ACTION ITEMS**\n" +
      "There is insufficient information in the provided content to identify priority actions.\n\n" +
      "**RESPONSIBILITIES AND ASSIGNMENTS**\n" +
      "There is insufficient information in the provided content to identify responsible parties.\n\n" +
      "**NEXT STEPS AND TIMELINE**\n" +
      "There is insufficient information in the provided content to detail next steps.\n\n" +
      "**DECISIONS MADE**\n" +
      "There is insufficient information in the provided content to list decisions.\n\n" +
      "**RISKS AND CONSIDERATIONS**\n" +
      "There is insufficient information in the provided content to identify risks."
    end
  end

  def generate_fallback_jira_tickets(content, language)
    if language == 'es'
      "**TICKETS JIRA (MODO BÁSICO)**\n\n" +
      "El contenido proporcionado contiene: #{content.length} caracteres.\n\n" +
      "**Épica: Análisis de Contenido**\n" +
      "Problema: No hay información suficiente para generar tickets específicos\n" +
      "Solución: Proporcionar contenido más detallado de la reunión\n" +
      "Contexto: El contenido actual es insuficiente para identificar tareas específicas\n\n" +
      "**Historia de Usuario: Mejora del Contenido**\n" +
      "Prioridad: Alta\n" +
      "Problema: Falta de información detallada sobre la reunión\n" +
      "Solución: Obtener transcripción completa o contenido más detallado\n" +
      "Criterios de Aceptación:\n" +
      "- Contenido debe incluir participantes identificados\n" +
      "- Contenido debe incluir temas discutidos\n" +
      "- Contenido debe incluir decisiones tomadas\n" +
      "Estimación: 1 día"
    else
      "**JIRA TICKETS (BASIC MODE)**\n\n" +
      "The provided content contains: #{content.length} characters.\n\n" +
      "**Epic: Content Analysis**\n" +
      "Problem: Insufficient information to generate specific tickets\n" +
      "Solution: Provide more detailed meeting content\n" +
      "Context: Current content is insufficient to identify specific tasks\n\n" +
      "**User Story: Content Improvement**\n" +
      "Priority: High\n" +
      "Problem: Lack of detailed information about the meeting\n" +
      "Solution: Obtain complete transcription or more detailed content\n" +
      "Acceptance Criteria:\n" +
      "- Content must include identified participants\n" +
      "- Content must include discussed topics\n" +
      "- Content must include decisions made\n" +
      "Estimation: 1 day"
    end
  end

  def generate_fallback_proposal(content, language)
    if language == 'es'
      "**PROPUESTA TÉCNICA (MODO BÁSICO)**\n\n" +
      "El contenido proporcionado contiene: #{content.length} caracteres.\n\n" +
      "**RESUMEN EJECUTIVO**\n" +
      "No hay información suficiente para generar una propuesta técnica completa.\n\n" +
      "**OBJETIVOS**\n" +
      "No hay información suficiente en el contenido proporcionado para identificar objetivos específicos.\n\n" +
      "**REQUISITOS TÉCNICOS**\n" +
      "No hay información suficiente en el contenido proporcionado para identificar requisitos técnicos.\n\n" +
      "**ARQUITECTURA PROPUESTA**\n" +
      "No hay información suficiente en el contenido proporcionado para proponer una arquitectura.\n\n" +
      "**CRONOGRAMA**\n" +
      "No hay información suficiente en el contenido proporcionado para establecer un cronograma.\n\n" +
      "**RECURSOS NECESARIOS**\n" +
      "No hay información suficiente en el contenido proporcionado para identificar recursos.\n\n" +
      "**RIESGOS Y MITIGACIONES**\n" +
      "No hay información suficiente en el contenido proporcionado para identificar riesgos."
    else
      "**TECHNICAL PROPOSAL (BASIC MODE)**\n\n" +
      "The provided content contains: #{content.length} characters.\n\n" +
      "**EXECUTIVE SUMMARY**\n" +
      "There is insufficient information to generate a complete technical proposal.\n\n" +
      "**OBJECTIVES**\n" +
      "There is insufficient information in the provided content to identify specific objectives.\n\n" +
      "**TECHNICAL REQUIREMENTS**\n" +
      "There is insufficient information in the provided content to identify technical requirements.\n\n" +
      "**PROPOSED ARCHITECTURE**\n" +
      "There is insufficient information in the provided content to propose an architecture.\n\n" +
      "**TIMELINE**\n" +
      "There is insufficient information in the provided content to establish a timeline.\n\n" +
      "**REQUIRED RESOURCES**\n" +
      "There is insufficient information in the provided content to identify resources.\n\n" +
      "**RISKS AND MITIGATIONS**\n" +
      "There is insufficient information in the provided content to identify risks."
    end
  end

  private

  def detect_language(content)
    # Detección simple basada en palabras clave
    spanish_indicators = ['el', 'la', 'de', 'que', 'y', 'en', 'un', 'es', 'se', 'no', 'te', 'lo', 'le', 'da', 'su', 'por', 'son', 'con', 'para', 'al', 'del', 'los', 'las', 'una', 'como', 'más', 'pero', 'sus', 'me', 'hasta', 'hay', 'donde', 'han', 'quien', 'están', 'estado', 'desde', 'todo', 'nos', 'durante', 'todos', 'uno', 'les', 'ni', 'contra', 'otros', 'ese', 'eso', 'ante', 'ellos', 'e', 'esto', 'mí', 'antes', 'algunos', 'qué', 'unos', 'yo', 'otro', 'otras', 'otra', 'él', 'tanto', 'esa', 'estos', 'mucho', 'quienes', 'nada', 'muchos', 'cual', 'poco', 'ella', 'estar', 'estas', 'algunas', 'algo', 'nosotros']
    english_indicators = ['the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i', 'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at', 'this', 'but', 'his', 'by', 'from', 'they', 'we', 'say', 'her', 'she', 'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their', 'what', 'so', 'up', 'out', 'if', 'about', 'who', 'get', 'which', 'go', 'me', 'when', 'make', 'can', 'like', 'time', 'no', 'just', 'him', 'know', 'take', 'people', 'into', 'year', 'your', 'good', 'some', 'could', 'them', 'see', 'other', 'than', 'then', 'now', 'look', 'only', 'come', 'its', 'over', 'think', 'also', 'back', 'after', 'use', 'two', 'how', 'our', 'work', 'first', 'well', 'way', 'even', 'new', 'want', 'because', 'any', 'these', 'give', 'day', 'most', 'us']
    
    # Contar palabras en español vs inglés
    spanish_count = spanish_indicators.count { |word| content.downcase.include?(word) }
    english_count = english_indicators.count { |word| content.downcase.include?(word) }
    
    if spanish_count > english_count
      'es'
    else
      'en'
    end
  end

  def build_translation_prompt(content, source_language, target_language)
    source_lang_name = source_language == 'es' ? 'Spanish' : 'English'
    target_lang_name = target_language == 'es' ? 'Spanish' : 'English'
    
    <<~PROMPT
      Translate the following content from #{source_lang_name} to #{target_lang_name}.
      
      IMPORTANT INSTRUCTIONS:
      1. Maintain the exact same structure and formatting (bold headers, bullet points, etc.)
      2. Keep all technical terms and proper nouns unchanged
      3. Preserve the meaning and tone of the original
      4. Do not add or remove any sections
      5. Translate only the text content, not the formatting markers like ** or -
      
      CONTENT TO TRANSLATE:
      #{content}
      
      TRANSLATION:
    PROMPT
  end

  def generate_no_content_message(content_type, language)
    if language == 'es'
      "No se pudo extraer contenido del archivo de tipo: #{content_type}\n\n" +
      "**POSIBLES SOLUCIONES:**\n" +
      "• Verifica que el archivo no esté corrupto\n" +
      "• Asegúrate de que el formato sea compatible\n" +
      "• Intenta con un archivo diferente"
    else
      "Could not extract content from file of type: #{content_type}\n\n" +
      "**POSSIBLE SOLUTIONS:**\n" +
      "• Verify that the file is not corrupted\n" +
      "• Make sure the format is compatible\n" +
      "• Try with a different file"
    end
  end

  def generate_unsupported_format_message(content_type, language)
    if language == 'es'
      "Formato de archivo no soportado: #{content_type}\n\n" +
      "**FORMATOS SOPORTADOS:**\n" +
      "• Texto (.txt, .md)\n" +
      "• PDF (.pdf)\n" +
      "• Word (.docx, .doc)\n" +
      "• Video (.mp4, .mov, .avi)\n" +
      "• Audio (.mp3, .wav, .m4a)"
    else
      "Unsupported file format: #{content_type}\n\n" +
      "**SUPPORTED FORMATS:**\n" +
      "• Text (.txt, .md)\n" +
      "• PDF (.pdf)\n" +
      "• Word (.docx, .doc)\n" +
      "• Video (.mp4, .mov, .avi)\n" +
      "• Audio (.mp3, .wav, .m4a)"
    end
  end

  def generate_video_fallback_message(language)
    if language == 'es'
      "⚠️ CONTENIDO DE VIDEO DETECTADO\n\n" +
      "El archivo es un video pero no se pudo transcribir automáticamente.\n\n" +
      "**SOLUCIONES RECOMENDADAS:**\n" +
      "1. **Otter.ai** - Transcripción automática gratuita\n" +
      "2. **Google Docs** - Herramienta de transcripción\n" +
      "3. **Microsoft Word** - Transcripción de audio\n\n" +
      "**PRÓXIMO PASO:**\n" +
      "Sube un archivo de texto (.txt) con la transcripción del video."
    else
      "⚠️ VIDEO CONTENT DETECTED\n\n" +
      "The file is a video but could not be transcribed automatically.\n\n" +
      "**RECOMMENDED SOLUTIONS:**\n" +
      "1. **Otter.ai** - Free automatic transcription\n" +
      "2. **Google Docs** - Transcription tool\n" +
      "3. **Microsoft Word** - Audio transcription\n\n" +
      "**NEXT STEP:**\n" +
      "Upload a text file (.txt) with the video transcription."
    end
  end

  def generate_audio_fallback_message(language)
    if language == 'es'
      "⚠️ CONTENIDO DE AUDIO DETECTADO\n\n" +
      "El archivo es de audio pero no se pudo transcribir automáticamente.\n\n" +
      "**SOLUCIONES RECOMENDADAS:**\n" +
      "1. **Otter.ai** - Transcripción automática gratuita\n" +
      "2. **Google Docs** - Herramienta de transcripción\n" +
      "3. **Microsoft Word** - Transcripción de audio\n\n" +
      "**PRÓXIMO PASO:**\n" +
      "Sube un archivo de texto (.txt) con la transcripción del audio."
    else
      "⚠️ AUDIO CONTENT DETECTED\n\n" +
      "The file is audio but could not be transcribed automatically.\n\n" +
      "**RECOMMENDED SOLUTIONS:**\n" +
      "1. **Otter.ai** - Free automatic transcription\n" +
      "2. **Google Docs** - Transcription tool\n" +
      "3. **Microsoft Word** - Audio transcription\n\n" +
      "**NEXT STEP:**\n" +
      "Upload a text file (.txt) with the audio transcription."
    end
  end
end
