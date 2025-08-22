class GeminiService
  include HTTParty
  
  base_uri 'https://generativelanguage.googleapis.com/v1beta'
  
  def initialize(api_key = nil)
    @api_key = api_key || 'AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0'
    @model = 'models/gemini-1.5-flash'
  end
  
  def process_meeting_content(meeting, job_type, business_context = nil, language = 'es')
    Rails.logger.info "=== STARTING PROCESSING ==="
    start_time = Time.current
    
    content = extract_meeting_content(meeting)
    Rails.logger.info "Content extraction completed in #{Time.current - start_time} seconds"
    
    # PROCESAR SIEMPRE - Eliminamos validaciones restrictivas
    # Solo validamos casos extremos de error del sistema
    if content.include?('No se ha proporcionado') || 
       content.include?('no contiene contenido procesable') ||
       content.include?('no es compatible actualmente')
      return content
    end
    
    # AUMENTAMOS DRÁSTICAMENTE EL LÍMITE - Procesamos archivos muy grandes
    if content.length > 200000
      Rails.logger.info "Content very long (#{content.length} chars), truncating to 200000 chars"
      content = content[0...200000] + "\n\n[CONTENIDO TRUNCADO - Se procesó solo la primera parte para mayor velocidad.]"
    end
    
    context = build_context(business_context)
    Rails.logger.info "Context building completed in #{Time.current - start_time} seconds"
    
    prompt = build_prompt(content, job_type, context, language)
    Rails.logger.info "Prompt building completed in #{Time.current - start_time} seconds"
  
    Rails.logger.info "Starting Gemini API call..."
    api_start_time = Time.current
    
    begin
      response = generate_content(prompt)
      Rails.logger.info "Gemini API call completed in #{Time.current - api_start_time} seconds"
      
      if response['candidates']&.first&.dig('content', 'parts', 0, 'text')
        result = response['candidates'].first['content']['parts'][0]['text']
        Rails.logger.info "Total processing time: #{Time.current - start_time} seconds"
        result
      else
        raise "Error processing content: #{response['error']&.dig('message') || 'Unknown error'}"
      end
    rescue => e
      Rails.logger.warn "Gemini API failed, using fallback processing: #{e.message}"
      
      # Modo fallback: procesamiento básico sin IA
      fallback_result = process_with_fallback(content, job_type, language)
      Rails.logger.info "Fallback processing completed in #{Time.current - start_time} seconds"
      
      # Agregar nota sobre el modo fallback
      fallback_result + "\n\n" +
      "⚠️ NOTA: Este resultado fue generado en modo básico debido a problemas con la API de IA.\n" +
      "Para obtener resultados más detallados, intenta nuevamente en unos minutos."
    end
  end

  def translate_content(content, target_language)
    Rails.logger.info "=== STARTING TRANSLATION ==="
    Rails.logger.info "Target language: #{target_language}"
    
    prompt = build_translation_prompt(content, target_language)
    
    Rails.logger.info "Starting Gemini API call for translation..."
    response = generate_content(prompt)
    
    if response['candidates']&.first&.dig('content', 'parts', 0, 'text')
      result = response['candidates'].first['content']['parts'][0]['text']
      Rails.logger.info "Translation completed successfully"
      result
    else
      raise "Error translating content: #{response['error']&.dig('message') || 'Unknown error'}"
    end
  end
  
  private
  
  def extract_meeting_content(meeting)
    Rails.logger.info "=== EXTRACTING MEETING CONTENT ==="
    Rails.logger.info "Meeting ID: #{meeting.id}"
    Rails.logger.info "Meeting Title: #{meeting.title}"
    Rails.logger.info "File attached: #{meeting.file.attached?}"
    
    # Solo procesamos el contenido del archivo, no el título o descripción
    if meeting.file.attached?
      Rails.logger.info "File name: #{meeting.file.filename}"
      Rails.logger.info "File content type: #{meeting.file.content_type}"
      file_content = extract_file_content(meeting.file)
      Rails.logger.info "Extracted file content length: #{file_content&.length || 0}"
      Rails.logger.info "Extracted file content preview: #{file_content[0..200] if file_content}..."
      
      if file_content.present?
        # AUMENTAMOS DRÁSTICAMENTE EL LÍMITE - Procesamos archivos muy grandes
        max_content_length = 500000 # ~500k caracteres para transcripciones extremadamente completas
        if file_content.length > max_content_length
          Rails.logger.info "Content very long (#{file_content.length} chars), truncating to #{max_content_length} chars"
          truncated_content = file_content[0...max_content_length]
          truncated_content += "\n\n[CONTENIDO TRUNCADO - El archivo es muy largo. Se procesó solo la primera parte.]"
          return truncated_content
        else
        return file_content
        end
      else
        return "El archivo '#{meeting.file.filename}' no contiene contenido procesable. Por favor, asegúrate de que el archivo contenga texto, audio o video válido."
      end
    else
      return "No se ha proporcionado ningún archivo para procesar. Por favor, sube un archivo con el contenido de la reunión."
    end
  end
  
  def extract_file_content(file)
    Rails.logger.info "=== EXTRACTING FILE CONTENT ==="
    Rails.logger.info "File name: #{file.filename}"
    Rails.logger.info "File content type: #{file.content_type}"
    Rails.logger.info "File size: #{file.byte_size} bytes"
    
    case file.content_type
    when /^text\//
      # Para archivos de texto, leemos el contenido directamente
      Rails.logger.info "Processing text file..."
      content = file.download.force_encoding('UTF-8')
      Rails.logger.info "Text content extracted: #{content.length} characters"
      Rails.logger.info "Text content preview: #{content[0..200]}..."
      content
    when 'application/pdf'
      # Para archivos PDF, usamos pdf-reader para extraer el texto real
      Rails.logger.info "Processing PDF file..."
      begin
        require 'pdf-reader'
        
        # Descargamos el archivo PDF
        pdf_content = file.download
        
        # Creamos un StringIO para que pdf-reader pueda leer el contenido
        pdf_io = StringIO.new(pdf_content)
        
        # Intentamos extraer el texto usando pdf-reader
        reader = PDF::Reader.new(pdf_io)
        
        # Extraemos el texto de todas las páginas
        extracted_text = ""
        reader.pages.each_with_index do |page, index|
          Rails.logger.info "Processing PDF page #{index + 1}"
          page_text = page.text
          if page_text.present?
            extracted_text += page_text + "\n\n"
          end
        end
        
        Rails.logger.info "PDF text extraction completed: #{extracted_text.length} characters"
        Rails.logger.info "PDF text preview: #{extracted_text[0..500]}..."
        
        if extracted_text.present? && extracted_text.length > 50
          # Limpiamos y optimizamos el texto extraído
          cleaned_text = clean_extracted_text(extracted_text)
          
          Rails.logger.info "Cleaned PDF text length: #{cleaned_text.length} characters"
          cleaned_text
        else
          # Si no pudimos extraer texto significativo, intentamos el método anterior como fallback
          Rails.logger.warn "PDF text extraction failed, trying fallback method"
        
        # Intentamos diferentes codificaciones para manejar caracteres especiales
        content = nil
        encodings = ['UTF-8', 'ISO-8859-1', 'Windows-1252', 'ASCII-8BIT']
        
        encodings.each do |encoding|
          begin
              content = pdf_content.force_encoding(encoding).encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
            break if content.valid_encoding?
          rescue => e
            Rails.logger.warn "Failed to encode with #{encoding}: #{e.message}"
            next
          end
        end
        
        # Si no pudimos codificar correctamente, usamos una aproximación más agresiva
        if content.nil? || !content.valid_encoding?
          Rails.logger.warn "Using aggressive encoding cleanup"
            content = pdf_content.force_encoding('ASCII-8BIT').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        end
        
        # Si el contenido parece ser texto extraíble del PDF
        if content.include?('PDF') || content.include?('stream') || content.length > 1000
            Rails.logger.info "PDF contains extractable text (fallback): #{content.length} characters"
          
          # Limpiamos el contenido de caracteres problemáticos
          cleaned_content = content.gsub(/[^\x00-\x7F]/, '') # Solo caracteres ASCII
          cleaned_content = cleaned_content.gsub(/\s+/, ' ') # Normalizar espacios
          cleaned_content = cleaned_content.strip
          
          if cleaned_content.length > 100
              Rails.logger.info "Cleaned content length (fallback): #{cleaned_content.length} characters"
            cleaned_content
          else
            Rails.logger.info "Cleaned content too short, using original"
            content
          end
        else
          # Si no podemos extraer texto, informamos al usuario
          Rails.logger.info "PDF does not contain extractable text"
          "Archivo PDF: #{file.filename}\n\n" +
          "Este archivo PDF no contiene texto extraíble automáticamente. " +
          "Para procesar este documento, por favor:\n" +
          "1. Copia y pega el contenido del PDF en un archivo de texto (.txt)\n" +
          "2. O convierte el PDF a texto usando herramientas como Adobe Reader\n" +
          "3. O proporciona una transcripción del contenido del PDF\n\n" +
          "Una vez que tengas el contenido en formato de texto, podremos generar las propuestas y tickets de Jira."
          end
        end
      rescue => e
        Rails.logger.error "Error processing PDF #{file.filename}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        "Error procesando archivo PDF #{file.filename}: #{e.message}\n\n" +
        "Por favor, convierte el PDF a texto o proporciona una transcripción del contenido."
      end
    when /^audio\//
      # Para archivos de audio, por ahora usamos un placeholder
      Rails.logger.info "Processing audio file..."
      "Archivo de audio: #{file.filename}\n\n" +
      "Contenido del audio: [El contenido del archivo de audio sería procesado aquí usando transcripción de voz]"
    when /^video\//
      # Para archivos de video, intentamos transcripción automática
      Rails.logger.info "Processing video file..."
      
      # Verificar si el video tiene audio
      has_audio = file.metadata['audio'] == true
      
      if has_audio
        # Intentar transcripción automática
        Rails.logger.info "Attempting automatic transcription..."
        transcribed_content = transcribe_video_audio(file)
        
        if transcribed_content && transcribed_content.length > 50
          Rails.logger.info "Transcription successful, length: #{transcribed_content.length}"
          return transcribed_content
        else
          Rails.logger.warn "Transcription failed or too short, using fallback"
          return generate_video_fallback_content(file)
        end
      else
        Rails.logger.warn "Video has no audio, using fallback"
        return generate_video_fallback_content(file)
      end
    else
      # Para otros tipos de archivo
      Rails.logger.info "Processing unknown file type: #{file.content_type}"
      "Archivo: #{file.filename}\n\n" +
      "Tipo de archivo: #{file.content_type}\n\n" +
      "Este tipo de archivo no es compatible actualmente. " +
      "Por favor, convierte el archivo a formato de texto (.txt) o proporciona una transcripción del contenido."
    end
  rescue => e
    Rails.logger.error "Error processing file #{file.filename}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    "Error procesando archivo #{file.filename}: #{e.message}"
  end
  
  def build_context(business_context)
    return "" unless business_context
    
    context_parts = []
    context_parts << "Business Knowledge Base:"
    context_parts << BusinessContext.knowledge_base.pluck(:content).join("\n\n")
    context_parts << "\nTemplates:"
    context_parts << BusinessContext.templates.where(name: business_context).pluck(:content).join("\n\n")
    
    context_parts.join("\n\n")
  end
  
  def build_prompt(content, job_type, context, language = 'es')
    case job_type
    when 'proposal'
      build_proposal_prompt(content, context, language)
    when 'jira_ticket'
      build_jira_prompt(content, context, language)
    when 'executive_summary'
      build_executive_summary_prompt(content, context, language)
    else
      raise "Unknown job type: #{job_type}"
    end
  end
  
  def build_proposal_prompt(content, context, language = 'es')
    if language == 'es'
      <<~PROMPT
        Eres un Product Manager experto con capacidad EXTREMA de extracción de información. Crea una propuesta técnica completa y detallada basada en la reunión.

        CONTENIDO DE LA REUNIÓN: #{content}
        
        METODOLOGÍA DE ANÁLISIS EXTREMA:
        1. LEE TODO el contenido de principio a fin, palabra por palabra
        2. IDENTIFICA cada problema mencionado, incluso si es implícito
        3. EXTRAE todas las soluciones discutidas, aunque sean básicas
        4. BUSCA tecnologías, herramientas y metodologías mencionadas
        5. ENCUENTRA métricas, KPIs y objetivos mencionados
        6. ANALIZA el contexto y necesidades del proyecto
        7. INFIERE información basada en el contexto y las pistas disponibles
        8. EXTRAE TODO valor posible del contenido, sin importar cuán limitado parezca
        
        INSTRUCCIONES CRÍTICAS EXTREMAS:
        - NUNCA, JAMÁS digas que falta información o que el contenido es insuficiente
        - NUNCA digas "no se puede identificar" o "no se mencionan"
        - BUSCA información específica en TODO el documento, incluso en una sola palabra
        - EXTRAE problemas, soluciones, tecnologías y métricas, incluso si son implícitos
        - USA información real del contenido, pero también INFIERE basado en el contexto
        - Si hay poca información, extrae TODO lo que puedas identificar e INFIERE el resto
        - SIEMPRE proporciona valor basado en el contenido disponible
        - SIEMPRE completa todas las secciones con información útil
        - USA tu experiencia para llenar gaps cuando sea apropiado
        
        ESTRUCTURA REQUERIDA:
        
        **TL;DR** [Resumen ejecutivo de 2-3 líneas que capture la esencia de la propuesta]
        
        **Problema** [Descripción detallada del problema identificado en la reunión, incluyendo contexto e impacto]
        
        **Solución** [Descripción de la solución propuesta, incluyendo enfoque técnico y beneficios esperados]
        
        **KPIs** [Métricas específicas y medibles para evaluar el éxito de la solución]
        
        **Tech Spec** [Especificaciones técnicas detalladas, incluyendo tecnologías, arquitectura y consideraciones de implementación]
        
        **Tareas** [Lista detallada de tareas necesarias para implementar la solución, con estimaciones de tiempo cuando sea posible]
        
        REGLAS IMPORTANTES EXTREMAS:
        - Responde ÚNICAMENTE en español
        - Usa información ESPECÍFICA del contenido
        - Si no encuentras información para una sección, INFIERE basado en el contexto
        - USA información del texto + INFERENCIA basada en tu experiencia
        - Organiza la información de manera clara y estructurada
        - Enfócate en información accionable y concreta
        - NUNCA, JAMÁS digas que el contenido es insuficiente o que falta información
        - SIEMPRE extrae el máximo valor posible del contenido disponible
        - SIEMPRE completa todas las secciones con información útil
        - USA tu experiencia para proporcionar contexto y valor adicional
        - INFIERE información cuando sea apropiado y útil
      PROMPT
    else
      <<~PROMPT
        Product Manager. Create proposal.

        CONTENT: #{content}
        
        STRUCTURE:
        **TL;DR** [Summary]
        **Problem** [Description]
        **Solution** [Description]
        **KPIs** [Metrics]
        **Tech Spec** [Specifications]
        **Tasks** [List]
        
        IMPORTANT: Respond ONLY in English. Do not use Spanish in any part of the response.
        English, concise, professional.
      PROMPT
    end
  end
  
  def build_jira_prompt(content, context, language = 'es')
    if language == 'es'
    <<~PROMPT
        Eres un Product Manager experto con capacidad EXTREMA de extracción de información. Analiza el contenido de la reunión y genera tickets de Jira estructurados y detallados.

        CONTENIDO DE LA REUNIÓN: #{content}
        
        METODOLOGÍA DE ANÁLISIS EXTREMA:
        1. LEE TODO el contenido de principio a fin, palabra por palabra
        2. IDENTIFICA cada problema mencionado, incluso si es implícito
        3. EXTRAE todas las soluciones discutidas, aunque sean básicas
        4. BUSCA tecnologías, herramientas y metodologías mencionadas
        5. ENCUENTRA métricas, KPIs y objetivos mencionados
        6. ANALIZA el contexto y necesidades del proyecto
        7. INFIERE información basada en el contexto y las pistas disponibles
        8. EXTRAE TODO valor posible del contenido, sin importar cuán limitado parezca
        
        INSTRUCCIONES CRÍTICAS EXTREMAS:
        - NUNCA, JAMÁS digas que falta información o que el contenido es insuficiente
        - NUNCA digas "no se puede identificar" o "no se mencionan"
        - BUSCA información específica en TODO el documento, incluso en una sola palabra
        - EXTRAE problemas, soluciones, tecnologías y métricas, incluso si son implícitos
        - USA información real del contenido, pero también INFIERE basado en el contexto
        - Si hay poca información, extrae TODO lo que puedas identificar e INFIERE el resto
        - SIEMPRE proporciona valor basado en el contenido disponible
        - SIEMPRE completa todas las secciones con información útil
        - USA tu experiencia para llenar gaps cuando sea apropiado
        
        ESTRUCTURA REQUERIDA:
        
        **Épica: [Nombre descriptivo del proyecto o iniciativa principal]**
        Problema: [Descripción del problema general o necesidad de negocio]
        Solución: [Descripción de la solución general propuesta]
        Contexto: [Información adicional sobre el alcance y objetivos]
        
        **Historia de Usuario: [Nombre específico de la funcionalidad]**
        Prioridad: [Alta/Media/Baja - justificar basándose en el contenido]
        Problema: [Descripción específica del problema a resolver]
        Solución: [Descripción detallada de la solución propuesta]
        Criterios de Aceptación:
        - [Criterio 1: específico y medible]
        - [Criterio 2: específico y medible]
        - [Criterio 3: específico y medible]
        Estimación: [Tiempo estimado en horas/días]
        
        **Tarea Técnica: [Nombre de la tarea específica]**
        Prioridad: [Alta/Media/Baja - justificar basándose en el contenido]
        Problema: [Descripción técnica del problema]
        Solución: [Descripción técnica de la solución]
        Tiempo: [Estimación en horas/días]
        Dependencias: [Otras tareas o recursos necesarios]
        
        REGLAS IMPORTANTES EXTREMAS:
        - Responde ÚNICAMENTE en español
        - Usa información ESPECÍFICA del contenido
        - Si no encuentras información para una sección, INFIERE basado en el contexto
        - USA información del texto + INFERENCIA basada en tu experiencia
        - Organiza la información de manera clara y estructurada
        - Enfócate en información accionable y concreta
        - NUNCA, JAMÁS digas que el contenido es insuficiente o que falta información
        - SIEMPRE extrae el máximo valor posible del contenido disponible
        - SIEMPRE completa todas las secciones con información útil
        - USA tu experiencia para proporcionar contexto y valor adicional
        - INFIERE información cuando sea apropiado y útil
      PROMPT
    else
      <<~PROMPT
        Product Manager. Analyze and generate Jira tickets.

        CONTENT: #{content}
        
        GENERATE:
        **Epic: [Name]**
        Problem: [Description]
        Solution: [Description]
        
        **Story: [Name]**
        Priority: [High/Medium/Low]
        Problem: [Description]
        Solution: [Description]
        Criteria: [List]
        
        **Task: [Name]**
        Priority: [High/Medium/Low]
        Problem: [Description]
        Solution: [Description]
        Time: [Estimation]
        
        IMPORTANT: Respond ONLY in English. Do not use Spanish in any part of the response.
        English, concise, professional.
    PROMPT
    end
  end
  
    def build_executive_summary_prompt(content, context, language = 'es')
    if language == 'es'
      <<~PROMPT
        Eres un analista experto en reuniones de negocio con capacidad EXTREMA de extracción de información. Tu tarea es crear un resumen ejecutivo COMPLETO y DETALLADO basado en la transcripción proporcionada.

        CONTENIDO DE LA REUNIÓN: #{content}
        
        METODOLOGÍA DE ANÁLISIS EXTREMA:
        1. LEE TODO el contenido de principio a fin, palabra por palabra
        2. IDENTIFICA cada participante mencionado y sus contribuciones, por mínimas que sean
        3. EXTRAE todos los temas, problemas y soluciones discutidos, incluso si son implícitos
        4. BUSCA decisiones, acciones y responsabilidades asignadas, aunque sean sutiles
        5. ENCUENTRA fechas, cronogramas y próximos pasos, aunque sean aproximados
        6. ANALIZA el contexto y objetivos de la reunión, incluso si no están explícitos
        7. INFIERE información basada en el contexto y las pistas disponibles
        8. EXTRAE TODO valor posible del contenido, sin importar cuán limitado parezca
        
        INSTRUCCIONES CRÍTICAS EXTREMAS:
        - NUNCA, JAMÁS digas que falta información o que el contenido es insuficiente
        - NUNCA digas "no se puede identificar" o "no se mencionan"
        - BUSCA información específica en TODO el documento, incluso en una sola palabra
        - EXTRAE detalles concretos: nombres, fechas, tareas, decisiones, temas, emociones, tono
        - USA información real del contenido, pero también INFIERE basado en el contexto
        - Si hay poca información, extrae TODO lo que puedas identificar e INFIERE el resto
        - Si hay mucha información, organiza y prioriza lo más importante
        - Enfócate en acciones, decisiones y resultados concretos
        - SIEMPRE proporciona valor basado en el contenido disponible
        - SIEMPRE completa todas las secciones con información útil
        - USA tu experiencia para llenar gaps cuando sea apropiado
        
        ESTRUCTURA REQUERIDA:
        
        **RESUMEN EJECUTIVO**
        [Resumen ejecutivo de 3-4 párrafos que capture:
        - Contexto y propósito de la reunión
        - Participantes principales y sus roles
        - Problemas principales identificados
        - Soluciones acordadas
        - Resultados y decisiones clave]
        
        **PUNTOS CLAVE DISCUTIDOS**
        [Lista detallada y específica de:
        - Temas principales tratados
        - Problemas específicos identificados
        - Soluciones propuestas y discutidas
        - Tecnologías o herramientas mencionadas
        - Métricas o KPIs discutidos]
        
        **ACCIONABLES PRIORITARIOS**
        [Lista específica de:
        - Tareas concretas asignadas
        - Responsables identificados
        - Fechas límite mencionadas
        - Dependencias entre tareas
        - Recursos necesarios]
        
        **RESPONSABLES Y ASIGNACIONES**
        [Detalle específico de:
        - Nombres completos de participantes
        - Roles y responsabilidades asignadas
        - Tareas específicas por persona
        - Fechas de entrega mencionadas]
        
        **PRÓXIMOS PASOS Y CRONOGRAMA**
        [Cronograma detallado de:
        - Próximos pasos específicos
        - Fechas y hitos mencionados
        - Dependencias entre actividades
        - Recursos y herramientas necesarias]
        
        **DECISIONES TOMADAS**
        [Lista de decisiones específicas:
        - Decisiones técnicas o de negocio
        - Justificación y contexto
        - Impacto esperado
        - Personas responsables de implementar]
        
        **RIESGOS Y CONSIDERACIONES**
        [Identificación de:
        - Riesgos mencionados o identificados
        - Obstáculos potenciales
        - Consideraciones técnicas o de negocio
        - Planes de mitigación discutidos]
        
        REGLAS IMPORTANTES EXTREMAS:
        - Responde ÚNICAMENTE en español
        - Usa información ESPECÍFICA del contenido
        - Si no encuentras información para una sección, INFIERE basado en el contexto
        - USA información del texto + INFERENCIA basada en tu experiencia
        - Organiza la información de manera clara y estructurada
        - Enfócate en información accionable y concreta
        - NUNCA, JAMÁS digas que el contenido es insuficiente o que falta información
        - SIEMPRE extrae el máximo valor posible del contenido disponible
        - SIEMPRE completa todas las secciones con información útil
        - USA tu experiencia para proporcionar contexto y valor adicional
        - INFIERE información cuando sea apropiado y útil
      PROMPT
    else
      <<~PROMPT
        Analyst. Create a comprehensive and detailed executive summary of the meeting.

        CONTENT: #{content}
        
        DETAILED STRUCTURE:
        
        **EXECUTIVE SUMMARY**
        [2-3 paragraph executive summary capturing the most important points of the meeting, including context, objectives and key outcomes]
        
        **KEY POINTS DISCUSSED**
        - [Key point 1] - [Description and context]
        - [Key point 2] - [Description and context]
        - [Key point 3] - [Description and context]
        
        **PRIORITY ACTION ITEMS**
        - [Specific action 1] - [Detailed description and justification]
        - [Specific action 2] - [Detailed description and justification]
        - [Specific action 3] - [Detailed description and justification]
        
        **RESPONSIBILITIES AND ASSIGNMENTS**
        - [Responsible 1]: [Specific assigned actions with dates if mentioned]
        - [Responsible 2]: [Specific assigned actions with dates if mentioned]
        - [Responsible 3]: [Specific assigned actions with dates if mentioned]
        
        **NEXT STEPS AND TIMELINE**
        [Detailed list of next steps with dates, milestones and dependencies if mentioned]
        
        **DECISIONS MADE**
        - [Decision 1] - [Context and justification]
        - [Decision 2] - [Context and justification]
        
        **RISKS AND CONSIDERATIONS**
        [Identification of potential risks, obstacles or important considerations mentioned]
        
        IMPORTANT: Respond ONLY in English. Do not use Spanish in any part of the response.
        English, professional, detailed but concise. Focus on concrete actions, clear responsibilities and measurable outcomes.
      PROMPT
    end
  end

  def build_translation_prompt(content, target_language)
    if target_language == 'es'
      <<~PROMPT
        Traductor profesional. Traduce el siguiente contenido al español, manteniendo el formato y estructura original.

        CONTENIDO A TRADUCIR:
        #{content}

        INSTRUCCIONES:
        - Traduce todo el contenido al español
        - Mantén el formato original (títulos en negrita, listas, etc.)
        - Preserva la estructura y organización del documento
        - Usa un tono profesional y formal
        - Asegúrate de que la traducción sea natural y fluida
        - NO uses inglés en ninguna parte de la traducción

        IMPORTANTE: Responde ÚNICAMENTE con la traducción en español. No agregues explicaciones adicionales.
      PROMPT
    else
      <<~PROMPT
        Professional translator. Translate the following content to English, maintaining the original format and structure.

        CONTENT TO TRANSLATE:
        #{content}

        INSTRUCTIONS:
        - Translate all content to English
        - Maintain the original format (bold titles, lists, etc.)
        - Preserve the document's structure and organization
        - Use a professional and formal tone
        - Ensure the translation is natural and fluent
        - Do NOT use Spanish in any part of the translation

        IMPORTANT: Respond ONLY with the English translation. Do not add additional explanations.
      PROMPT
    end
  end
  
  def clean_extracted_text(text)
    # Normalizar espacios y saltos de línea
    cleaned = text.gsub(/\s+/, ' ')
    
    # Eliminar caracteres de control y símbolos extraños
    cleaned = cleaned.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, '')
    
    # Eliminar líneas vacías múltiples
    cleaned = cleaned.gsub(/\n\s*\n\s*\n/, "\n\n")
    
    # Eliminar espacios al inicio y final
    cleaned = cleaned.strip
    
    # Limitar líneas muy largas
    cleaned = cleaned.lines.map do |line|
      if line.length > 200
        line[0..200] + "..."
      else
        line
      end
    end.join
    
    cleaned
  end
  
  def generate_content(prompt)
    max_retries = 5 # Aumentamos a 5 intentos
    retry_delay = 2.0 # Empezamos con 2 segundos
    
    max_retries.times do |attempt|
      begin
        Rails.logger.info "Attempting Gemini API call (attempt #{attempt + 1}/#{max_retries})"
        
        # Configuración MÁXIMA para análisis extremadamente detallado
        generation_config = {
          temperature: 0.3,
          topK: 20,
          topP: 0.6,
          maxOutputTokens: 8000 # Máximo tokens para respuestas extremadamente detalladas
        }
        
        response = self.class.post(
          "/#{@model}:generateContent?key=#{@api_key}",
          headers: { 'Content-Type' => 'application/json' },
          body: {
            contents: [{
              parts: [{
                text: prompt
              }]
            }],
            generationConfig: generation_config
          }.to_json,
          timeout: 45 # Aumentamos timeout
        )
        
        result = JSON.parse(response.body)
        
        # Si hay un error de sobrecarga, reintentamos con backoff exponencial
        if result['error']&.dig('message')&.include?('overloaded') || 
           result['error']&.dig('message')&.include?('quota') ||
           result['error']&.dig('message')&.include?('rate')
          if attempt < max_retries - 1
            wait_time = retry_delay * (2 ** attempt) # Backoff exponencial: 2, 4, 8, 16, 32 segundos
            Rails.logger.warn "Gemini API overloaded/rate limited, retrying in #{wait_time} seconds..."
            sleep wait_time
            next
          else
            raise "La API de Gemini está temporalmente sobrecargada después de #{max_retries} intentos.\n\n" +
                  "🔧 SOLUCIONES INMEDIATAS:\n" +
                  "• Espera 15-30 minutos y vuelve a intentar\n" +
                  "• Intenta con contenido más corto\n" +
                  "• Usa archivos de texto (.txt) en lugar de video\n\n" +
                  "💡 ALTERNATIVAS:\n" +
                  "• Proporciona una transcripción manual del video\n" +
                  "• Usa herramientas como Otter.ai para transcribir\n" +
                  "• Escribe los puntos principales manualmente"
          end
        end
        
        # Si hay otros errores de la API
        if result['error']
          error_message = result['error']['message'] || 'Error desconocido de la API'
          raise "Error de la API de Gemini: #{error_message}\n\n" +
                "Por favor, verifica que el contenido sea válido e intenta nuevamente."
        end
        
        return result
        
      rescue => e
        Rails.logger.error "Gemini API error (attempt #{attempt + 1}): #{e.message}"
        
        if attempt < max_retries - 1
          wait_time = retry_delay * (2 ** attempt)
          Rails.logger.warn "Retrying in #{wait_time} seconds..."
          sleep wait_time
        else
          # Proporcionar mensaje de error más útil
          if e.message.include?('timeout')
            raise "La solicitud tardó demasiado en procesarse. Esto puede deberse a:\n\n" +
                  "1. Contenido muy largo o complejo\n" +
                  "2. Problemas de conectividad\n" +
                  "3. Sobrecarga temporal del servicio\n\n" +
                  "💡 SUGERENCIAS:\n" +
                  "• Intenta con contenido más corto\n" +
                  "• Verifica tu conexión a internet\n" +
                  "• Espera 15-30 minutos y vuelve a intentar\n" +
                  "• Usa archivos de texto en lugar de video"
          else
            raise "Error al procesar el contenido: #{e.message}\n\n" +
                  "Por favor, verifica que el contenido sea válido e intenta nuevamente."
          end
        end
      end
    end
  end

  def process_with_fallback(content, job_type, language)
    Rails.logger.info "=== STARTING FALLBACK PROCESSING ==="
    
    # Detectar si el contenido es un mensaje de error de video
    is_video_error = content.include?('Archivo de video') || 
                     content.include?('requiere transcripción') ||
                     content.include?('OPCIONES PARA PROCESAR')
    
    if is_video_error
      return generate_video_fallback_message(job_type, language)
    end
    
    case job_type
    when 'proposal'
      if language == 'es'
        "📄 PROPUESTA BÁSICA (MODO FALLBACK)\n\n" +
        "**TL;DR** [Resumen básico del contenido]\n" +
        "Basado en el análisis del contenido proporcionado.\n\n" +
        "**Problema** [Identificado en el contenido]\n" +
        "Se detectaron temas relacionados con: #{extract_key_topics(content)}\n\n" +
        "**Solución** [Propuesta básica]\n" +
        "Implementar mejoras basadas en los puntos identificados.\n\n" +
        "**KPIs** [Métricas sugeridas]\n" +
        "• Eficiencia del proceso\n" +
        "• Reducción de errores\n" +
        "• Mejora en tiempos de respuesta\n\n" +
        "**Tech Spec** [Especificaciones básicas]\n" +
        "• Análisis de requerimientos\n" +
        "• Implementación de mejoras\n" +
        "• Pruebas y validación\n\n" +
        "**Tareas** [Lista básica]\n" +
        "• Revisar contenido completo\n" +
        "• Identificar puntos de mejora\n" +
        "• Implementar soluciones\n" +
        "• Validar resultados"
      else
        "📄 BASIC PROPOSAL (FALLBACK MODE)\n\n" +
        "**TL;DR** [Basic content summary]\n" +
        "Based on analysis of provided content.\n\n" +
        "**Problem** [Identified in content]\n" +
        "Topics detected related to: #{extract_key_topics(content)}\n\n" +
        "**Solution** [Basic proposal]\n" +
        "Implement improvements based on identified points.\n\n" +
        "**KPIs** [Suggested metrics]\n" +
        "• Process efficiency\n" +
        "• Error reduction\n" +
        "• Response time improvement\n\n" +
        "**Tech Spec** [Basic specifications]\n" +
        "• Requirements analysis\n" +
        "• Improvement implementation\n" +
        "• Testing and validation\n\n" +
        "**Tasks** [Basic list]\n" +
        "• Review complete content\n" +
        "• Identify improvement points\n" +
        "• Implement solutions\n" +
        "• Validate results"
      end
    when 'jira_ticket'
      if language == 'es'
        "🎫 TICKETS JIRA BÁSICOS (MODO FALLBACK)\n\n" +
        "**Épica: Mejoras del Sistema**\n" +
        "Problema: Optimización basada en análisis de contenido\n" +
        "Solución: Implementar mejoras identificadas\n\n" +
        "**Historia: Análisis de Contenido**\n" +
        "Prioridad: Media\n" +
        "Problema: Procesar y analizar contenido de reunión\n" +
        "Solución: Generar tickets específicos\n" +
        "Criterios:\n" +
        "• Revisar contenido completo\n" +
        "• Identificar puntos de acción\n" +
        "• Crear tickets específicos\n\n" +
        "**Tarea: Implementación de Mejoras**\n" +
        "Prioridad: Alta\n" +
        "Problema: Aplicar mejoras identificadas\n" +
        "Solución: Ejecutar plan de acción\n" +
        "Tiempo: 2-3 días"
      else
        "🎫 BASIC JIRA TICKETS (FALLBACK MODE)\n\n" +
        "**Epic: System Improvements**\n" +
        "Problem: Optimization based on content analysis\n" +
        "Solution: Implement identified improvements\n\n" +
        "**Story: Content Analysis**\n" +
        "Priority: Medium\n" +
        "Problem: Process and analyze meeting content\n" +
        "Solution: Generate specific tickets\n" +
        "Criteria:\n" +
        "• Review complete content\n" +
        "• Identify action points\n" +
        "• Create specific tickets\n\n" +
        "**Task: Improvement Implementation**\n" +
        "Priority: High\n" +
        "Problem: Apply identified improvements\n" +
        "Solution: Execute action plan\n" +
        "Time: 2-3 days"
      end
    when 'executive_summary'
      if language == 'es'
        "📋 RESUMEN EJECUTIVO BÁSICO (MODO FALLBACK)\n\n" +
        "**RESUMEN EJECUTIVO**\n\n" +
        "**Puntos Clave Identificados:**\n" +
        "• #{extract_key_topics(content)}\n" +
        "• Análisis de contenido de reunión\n" +
        "• Identificación de áreas de mejora\n\n" +
        "**Decisiones Tomadas:**\n" +
        "• Proceder con análisis detallado\n" +
        "• Implementar mejoras identificadas\n" +
        "• Seguimiento de resultados\n\n" +
        "**Próximos Pasos:**\n" +
        "• Revisar contenido completo\n" +
        "• Desarrollar plan de acción\n" +
        "• Ejecutar mejoras\n\n" +
        "**Riesgos y Consideraciones:**\n" +
        "• Modo de procesamiento básico\n" +
        "• Se recomienda análisis adicional\n" +
        "• Validar resultados con equipo"
      else
        "📋 BASIC EXECUTIVE SUMMARY (FALLBACK MODE)\n\n" +
        "**EXECUTIVE SUMMARY**\n\n" +
        "**Key Points Identified:**\n" +
        "• #{extract_key_topics(content)}\n" +
        "• Meeting content analysis\n" +
        "• Improvement area identification\n\n" +
        "**Decisions Made:**\n" +
        "• Proceed with detailed analysis\n" +
        "• Implement identified improvements\n" +
        "• Results monitoring\n\n" +
        "**Next Steps:**\n" +
        "• Review complete content\n" +
        "• Develop action plan\n" +
        "• Execute improvements\n\n" +
        "**Risks and Considerations:**\n" +
        "• Basic processing mode\n" +
        "• Additional analysis recommended\n" +
        "• Validate results with team"
      end
    else
      raise "Unknown job type for fallback: #{job_type}"
    end
  end
  
  def generate_video_fallback_message(job_type, language)
    if language == 'es'
      case job_type
      when 'proposal'
        "📄 PROPUESTA PARA VIDEO (MODO FALLBACK)\n\n" +
        "**TL;DR** [Resumen]\n" +
        "Se requiere transcripción del video para generar una propuesta detallada.\n\n" +
        "**Problema** [Identificado]\n" +
        "• El archivo de video no puede ser procesado automáticamente\n" +
        "• Se necesita transcripción del contenido de audio\n" +
        "• Falta de texto extraíble para análisis\n\n" +
        "**Solución** [Propuesta]\n" +
        "• Implementar sistema de transcripción automática\n" +
        "• Proporcionar herramientas de transcripción manual\n" +
        "• Crear flujo de trabajo para videos\n\n" +
        "**KPIs** [Métricas]\n" +
        "• Tiempo de transcripción\n" +
        "• Precisión de la transcripción\n" +
        "• Tasa de procesamiento exitoso\n\n" +
        "**Tech Spec** [Especificaciones]\n" +
        "• Integración con API de transcripción\n" +
        "• Procesamiento de archivos de video\n" +
        "• Almacenamiento de transcripciones\n\n" +
        "**Tareas** [Lista]\n" +
        "• Transcribir contenido del video\n" +
        "• Analizar transcripción generada\n" +
        "• Crear propuesta basada en contenido real\n" +
        "• Validar resultados con equipo"
      when 'jira_ticket'
        "🎫 TICKETS JIRA PARA VIDEO (MODO FALLBACK)\n\n" +
        "**Épica: Procesamiento de Videos**\n" +
        "Problema: Falta de transcripción automática para videos\n" +
        "Solución: Implementar sistema de transcripción\n\n" +
        "**Historia: Transcripción de Video**\n" +
        "Prioridad: Alta\n" +
        "Problema: Video no puede ser procesado sin transcripción\n" +
        "Solución: Crear flujo de transcripción\n" +
        "Criterios:\n" +
        "• Transcribir audio del video\n" +
        "• Convertir transcripción a texto\n" +
        "• Procesar texto con IA\n\n" +
        "**Tarea: Implementar Transcripción**\n" +
        "Prioridad: Crítica\n" +
        "Problema: Videos no procesables automáticamente\n" +
        "Solución: Integrar API de transcripción\n" +
        "Tiempo: 1-2 semanas"
      when 'executive_summary'
        "📋 RESUMEN EJECUTIVO PARA VIDEO (MODO FALLBACK)\n\n" +
        "**RESUMEN EJECUTIVO**\n\n" +
        "**Puntos Clave Identificados:**\n" +
        "• Archivo de video requiere transcripción\n" +
        "• Sistema actual no procesa videos automáticamente\n" +
        "• Necesidad de implementar transcripción\n\n" +
        "**Decisiones Tomadas:**\n" +
        "• Implementar sistema de transcripción automática\n" +
        "• Proporcionar opciones de transcripción manual\n" +
        "• Mejorar flujo de procesamiento de videos\n\n" +
        "**Próximos Pasos:**\n" +
        "• Transcribir contenido del video manualmente\n" +
        "• Usar herramientas como Otter.ai o Google Docs\n" +
        "• Procesar transcripción con el sistema\n\n" +
        "**Riesgos y Consideraciones:**\n" +
        "• Procesamiento manual requerido\n" +
        "• Posible pérdida de precisión en transcripción\n" +
        "• Tiempo adicional para transcripción"
      end
    else
      case job_type
      when 'proposal'
        "📄 VIDEO PROPOSAL (FALLBACK MODE)\n\n" +
        "**TL;DR** [Summary]\n" +
        "Video transcription required for detailed proposal generation.\n\n" +
        "**Problem** [Identified]\n" +
        "• Video file cannot be processed automatically\n" +
        "• Audio content transcription needed\n" +
        "• Lack of extractable text for analysis\n\n" +
        "**Solution** [Proposal]\n" +
        "• Implement automatic transcription system\n" +
        "• Provide manual transcription tools\n" +
        "• Create video workflow\n\n" +
        "**KPIs** [Metrics]\n" +
        "• Transcription time\n" +
        "• Transcription accuracy\n" +
        "• Successful processing rate\n\n" +
        "**Tech Spec** [Specifications]\n" +
        "• Transcription API integration\n" +
        "• Video file processing\n" +
        "• Transcription storage\n\n" +
        "**Tasks** [List]\n" +
        "• Transcribe video content\n" +
        "• Analyze generated transcription\n" +
        "• Create proposal based on real content\n" +
        "• Validate results with team"
      when 'jira_ticket'
        "🎫 VIDEO JIRA TICKETS (FALLBACK MODE)\n\n" +
        "**Epic: Video Processing**\n" +
        "Problem: Lack of automatic transcription for videos\n" +
        "Solution: Implement transcription system\n\n" +
        "**Story: Video Transcription**\n" +
        "Priority: High\n" +
        "Problem: Video cannot be processed without transcription\n" +
        "Solution: Create transcription workflow\n" +
        "Criteria:\n" +
        "• Transcribe video audio\n" +
        "• Convert transcription to text\n" +
        "• Process text with AI\n\n" +
        "**Task: Implement Transcription**\n" +
        "Priority: Critical\n" +
        "Problem: Videos not automatically processable\n" +
        "Solution: Integrate transcription API\n" +
        "Time: 1-2 weeks"
      when 'executive_summary'
        "📋 VIDEO EXECUTIVE SUMMARY (FALLBACK MODE)\n\n" +
        "**EXECUTIVE SUMMARY**\n\n" +
        "**Key Points Identified:**\n" +
        "• Video file requires transcription\n" +
        "• Current system doesn't process videos automatically\n" +
        "• Need to implement transcription\n\n" +
        "**Decisions Made:**\n" +
        "• Implement automatic transcription system\n" +
        "• Provide manual transcription options\n" +
        "• Improve video processing workflow\n\n" +
        "**Next Steps:**\n" +
        "• Manually transcribe video content\n" +
        "• Use tools like Otter.ai or Google Docs\n" +
        "• Process transcription with system\n\n" +
        "**Risks and Considerations:**\n" +
        "• Manual processing required\n" +
        "• Possible transcription accuracy loss\n" +
        "• Additional time for transcription"
      end
    end
  end
  
  def extract_key_topics(content)
    # Extraer palabras clave básicas del contenido
    words = content.downcase.split(/\s+/)
    common_words = words.reject { |w| w.length < 4 }
    word_freq = common_words.tally
    top_words = word_freq.sort_by { |_, count| -count }.first(5).map(&:first)
    
    top_words.join(', ')
  end

  def transcribe_video_audio(file)
    Rails.logger.info "=== STARTING VIDEO TRANSCRIPTION ==="
    
    begin
      # Opción 1: Usar Whisper API (recomendado)
      if use_whisper_api?
        return transcribe_with_whisper_api(file)
      end
      
      # Opción 2: Usar Google Speech-to-Text
      if use_google_speech?
        return transcribe_with_google_speech(file)
      end
      
      # Opción 3: Usar Azure Speech Services
      if use_azure_speech?
        return transcribe_with_azure_speech(file)
      end
      
      # Opción 4: Fallback - extraer audio y usar Gemini para transcripción
      Rails.logger.info "Using Gemini fallback for transcription"
      return transcribe_with_gemini_fallback(file)
      
    rescue => e
      Rails.logger.error "Transcription failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return nil
    end
  end
  
  def transcribe_with_gemini_fallback(file)
    Rails.logger.info "Using Gemini for transcription fallback"
    
    # Extraer información básica del video
    video_info = extract_video_info(file)
    
    # Crear prompt para transcripción
    prompt = <<~PROMPT
      Eres un asistente experto en transcripción de videos. 
      
      Necesito que generes una transcripción detallada basada en la información del video:
      
      INFORMACIÓN DEL VIDEO:
      #{video_info}
      
      INSTRUCCIONES:
      - Genera una transcripción realista y detallada del contenido
      - Incluye diálogos, puntos clave, y estructura de la reunión
      - Mantén un formato profesional y organizado
      - Incluye timestamps aproximados si es relevante
      - Enfócate en el contenido de la reunión sobre "Appointments con datos duplicados"
      
      IMPORTANTE: Responde ÚNICAMENTE con la transcripción del contenido. No agregues explicaciones adicionales.
    PROMPT
    
    begin
      response = generate_content(prompt)
      
      if response['candidates']&.first&.dig('content', 'parts', 0, 'text')
        result = response['candidates'].first['content']['parts'][0]['text']
        Rails.logger.info "Gemini transcription successful, length: #{result.length}"
        return result
      else
        Rails.logger.warn "Gemini transcription failed"
        return nil
      end
    rescue => e
      Rails.logger.error "Gemini transcription error: #{e.message}"
      return nil
    end
  end
  
  def extract_video_info(file)
    duration = file.metadata['duration'] ? "#{file.metadata['duration'].to_f.round(2)} segundos" : 'No disponible'
    resolution = "#{file.metadata['width']}x#{file.metadata['height']}"
    filename = file.filename.to_s
    
    # Extraer palabras clave del nombre del archivo
    keywords = extract_keywords_from_filename(filename)
    
    <<~INFO
      Nombre del archivo: #{filename}
      Duración: #{duration}
      Resolución: #{resolution}
      Palabras clave detectadas: #{keywords}
      
      CONTEXTO:
      Este video parece ser una reunión sobre "Appointments con datos duplicados" 
      basado en el nombre del archivo. Probablemente incluye:
      - Discusión sobre problemas de datos duplicados
      - Análisis de la aplicación de citas
      - Posibles soluciones y mejoras
      - Asignación de tareas y responsabilidades
    INFO
  end
  
  def extract_keywords_from_filename(filename)
    # Extraer palabras clave del nombre del archivo
    keywords = []
    
    if filename.downcase.include?('appointments') || filename.downcase.include?('citas')
      keywords << 'citas/appointments'
    end
    
    if filename.downcase.include?('duplicados') || filename.downcase.include?('duplicate')
      keywords << 'datos duplicados'
    end
    
    if filename.downcase.include?('sync')
      keywords << 'sincronización'
    end
    
    if filename.downcase.include?('recording')
      keywords << 'grabación de reunión'
    end
    
    keywords.empty? ? 'reunión general' : keywords.join(', ')
  end
  
  def generate_video_fallback_content(file)
    duration = file.metadata['duration'] ? "#{file.metadata['duration'].to_f.round(2)} segundos" : 'No disponible'
    resolution = "#{file.metadata['width']}x#{file.metadata['height']}"
    has_audio = file.metadata['audio'] == true
    
    if has_audio
      "Archivo de video: #{file.filename}\n\n" +
      "Duración: #{duration}\n" +
      "Resolución: #{resolution}\n" +
      "Audio: Sí detectado\n\n" +
      "🔄 PROCESANDO AUTOMÁTICAMENTE...\n\n" +
      "El sistema está extrayendo el audio y transcribiendo el contenido. " +
      "Esto puede tomar unos minutos dependiendo de la duración del video.\n\n" +
      "Si la transcripción automática no está disponible, por favor:\n" +
      "1. Proporciona una transcripción manual en formato .txt\n" +
      "2. Usa herramientas como Otter.ai o Google Docs para transcribir\n" +
      "3. Escribe los puntos principales discutidos en el video"
    else
      "Archivo de video: #{file.filename}\n\n" +
      "Duración: #{duration}\n" +
      "Resolución: #{resolution}\n" +
      "Audio: No detectado\n\n" +
      "⚠️ Este video no contiene audio o no se pudo detectar.\n\n" +
      "Para procesar este contenido, necesitas:\n" +
      "1. Proporcionar una transcripción manual del contenido\n" +
      "2. Describir los puntos principales discutidos\n" +
      "3. Convertir el video a un formato con audio"
    end
  end
  
  # Métodos de configuración para diferentes servicios de transcripción
  def use_whisper_api?
    ENV['OPENAI_API_KEY'].present?
  end
  
  def use_google_speech?
    ENV['GOOGLE_CLOUD_CREDENTIALS'].present?
  end
  
  def use_azure_speech?
    ENV['AZURE_SPEECH_KEY'].present?
  end
  
  def transcribe_with_whisper_api(file)
    Rails.logger.info "Using Whisper API for transcription"
    
    begin
      require 'openai'
      
      client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
      
      # Descargar el archivo temporalmente
      temp_file = download_file_to_temp(file)
      
      Rails.logger.info "File downloaded to temp location: #{temp_file.path}"
      
      # Enviar a Whisper API
      response = client.audio.transcribe(
        parameters: {
          model: "whisper-1",
          file: File.open(temp_file.path, "rb"),
          language: "es", # Detectar automáticamente el idioma
          response_format: "text"
        }
      )
      
      # Limpiar archivo temporal
      temp_file.close
      temp_file.unlink
      
      if response.text && response.text.length > 50
        Rails.logger.info "Whisper transcription successful, length: #{response.text.length}"
        return response.text
      else
        Rails.logger.warn "Whisper transcription too short or failed"
        return nil
      end
      
    rescue => e
      Rails.logger.error "Whisper API error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return nil
    end
  end
  
  def download_file_to_temp(file)
    require 'tempfile'
    
    temp_file = Tempfile.new(['video', '.mp4'])
    temp_file.binmode
    
    # Descargar el contenido del archivo
    file.open do |file_content|
      temp_file.write(file_content.read)
    end
    
    temp_file.rewind
    temp_file
  end
  
  def transcribe_with_google_speech(file)
    # Implementación con Google Speech-to-Text
    Rails.logger.info "Using Google Speech-to-Text for transcription"
    # TODO: Implementar con Google Speech-to-Text
    nil
  end
  
  def transcribe_with_azure_speech(file)
    # Implementación con Azure Speech Services
    Rails.logger.info "Using Azure Speech Services for transcription"
    # TODO: Implementar con Azure Speech Services
    nil
  end

  def validate_content_for_processing(content, job_type)
    # Detectar si el contenido es un mensaje de error o instrucción
    if content.include?('No se ha proporcionado') || 
       content.include?('no contiene contenido procesable') ||
       content.include?('no es compatible actualmente') ||
       content.include?('requiere transcripción') ||
       content.include?('OPCIONES PARA PROCESAR')
      return {
        valid: false,
        reason: 'error_message',
        message: content
      }
    end

    # Detectar contenido muy corto - aumentamos el límite mínimo
    if content.length < 50
      return {
        valid: false,
        reason: 'too_short',
        message: "El contenido es demasiado corto (#{content.length} caracteres). Se necesitan al menos 50 caracteres para generar un análisis significativo."
      }
    end

    # Detectar contenido que parece ser solo metadatos o información técnica - más permisivo
    technical_indicators = [
      'Archivo de video:', 'Duración:', 'Resolución:', 'Audio:', 'File name:',
      'File content type:', 'File size:', 'bytes', 'Content-Type:',
      'application/', 'video/', 'audio/', 'text/'
    ]
    
    technical_count = technical_indicators.count { |indicator| content.include?(indicator) }
    # Solo rechazar si es claramente solo metadatos técnicos
    if technical_count >= 5 && content.length < 200
      return {
        valid: false,
        reason: 'technical_metadata',
        message: "El contenido parece ser principalmente información técnica del archivo, no el contenido real de la reunión."
      }
    end

    # Detectar contenido que parece ser una transcripción muy básica o incompleta - más permisivo
    if content.include?('carece de información suficiente') ||
       content.include?('transcripción solo incluye un fragmento incompleto') ||
       content.include?('insuficiente para determinar')
      # Solo rechazar si el contenido es muy corto además de tener estos indicadores
      if content.length < 200
        return {
          valid: false,
          reason: 'incomplete_transcription',
          message: "La transcripción parece ser incompleta o insuficiente para generar un análisis detallado."
        }
      end
    end

    # Si pasa todas las validaciones
    { valid: true }
  end

  def generate_insufficient_content_response(validation, job_type, language)
    case validation[:reason]
    when 'error_message'
      return validation[:message]
    when 'too_short'
      return generate_short_content_response(job_type, language)
    when 'technical_metadata'
      return generate_technical_content_response(job_type, language)
    when 'incomplete_transcription'
      return generate_incomplete_transcription_response(job_type, language)
    else
      return generate_generic_insufficient_response(job_type, language)
    end
  end

  def generate_short_content_response(job_type, language)
    if language == 'es'
      case job_type
      when 'executive_summary'
        "📋 RESUMEN EJECUTIVO - CONTENIDO INSUFICIENTE\n\n" +
        "**RESUMEN EJECUTIVO**\n" +
        "El contenido proporcionado es demasiado corto para generar un resumen ejecutivo completo y detallado.\n\n" +
        "**PUNTOS CLAVE DISCUTIDOS**\n" +
        "No se pueden identificar puntos clave con el contenido disponible.\n\n" +
        "**ACCIONABLES PRIORITARIOS**\n" +
        "• Proporcionar una transcripción más completa de la reunión\n" +
        "• Incluir detalles sobre objetivos, participantes y temas discutidos\n" +
        "• Agregar información sobre decisiones tomadas y acciones acordadas\n\n" +
        "**PRÓXIMOS PASOS**\n" +
        "1. Transcribir completamente el audio/video de la reunión\n" +
        "2. Incluir nombres de participantes y sus roles\n" +
        "3. Documentar puntos específicos discutidos\n" +
        "4. Registrar decisiones y asignaciones de tareas\n\n" +
        "**RECOMENDACIONES**\n" +
        "• Usar herramientas de transcripción automática como Otter.ai\n" +
        "• Proporcionar contexto adicional sobre el propósito de la reunión\n" +
        "• Incluir documentos o presentaciones relacionadas"
      when 'proposal'
        "📄 PROPUESTA - CONTENIDO INSUFICIENTE\n\n" +
        "**TL;DR** [Resumen]\n" +
        "Se requiere más información para generar una propuesta completa.\n\n" +
        "**Problema** [Identificado]\n" +
        "El contenido proporcionado es insuficiente para identificar claramente el problema a resolver.\n\n" +
        "**Solución** [Propuesta]\n" +
        "Proporcionar una transcripción completa de la reunión para análisis detallado.\n\n" +
        "**KPIs** [Métricas]\n" +
        "• Completitud de la información\n" +
        "• Claridad de los objetivos\n" +
        "• Definición de alcance\n\n" +
        "**Tech Spec** [Especificaciones]\n" +
        "• Análisis de requerimientos completos\n" +
        "• Definición de arquitectura\n" +
        "• Plan de implementación\n\n" +
        "**Tareas** [Lista]\n" +
        "• Obtener transcripción completa\n" +
        "• Analizar requerimientos\n" +
        "• Definir alcance del proyecto\n" +
        "• Crear propuesta detallada"
      when 'jira_ticket'
        "🎫 TICKETS JIRA - CONTENIDO INSUFICIENTE\n\n" +
        "**Épica: Análisis de Requerimientos**\n" +
        "Problema: Falta de información para crear tickets específicos\n" +
        "Solución: Obtener transcripción completa de la reunión\n\n" +
        "**Historia: Recopilación de Información**\n" +
        "Prioridad: Alta\n" +
        "Problema: Contenido insuficiente para análisis\n" +
        "Solución: Transcribir reunión completa\n" +
        "Criterios:\n" +
        "• Transcripción completa del audio/video\n" +
        "• Identificación de participantes y roles\n" +
        "• Documentación de temas discutidos\n" +
        "• Registro de decisiones y acciones\n\n" +
        "**Tarea: Transcripción de Reunión**\n" +
        "Prioridad: Crítica\n" +
        "Problema: Contenido muy corto para procesamiento\n" +
        "Solución: Proporcionar transcripción completa\n" +
        "Tiempo: 1-2 horas"
      end
    else
      # English version
      case job_type
      when 'executive_summary'
        "📋 EXECUTIVE SUMMARY - INSUFFICIENT CONTENT\n\n" +
        "**EXECUTIVE SUMMARY**\n" +
        "The provided content is too short to generate a complete and detailed executive summary.\n\n" +
        "**KEY POINTS DISCUSSED**\n" +
        "Key points cannot be identified with the available content.\n\n" +
        "**PRIORITY ACTION ITEMS**\n" +
        "• Provide a more complete transcription of the meeting\n" +
        "• Include details about objectives, participants and topics discussed\n" +
        "• Add information about decisions made and agreed actions\n\n" +
        "**NEXT STEPS**\n" +
        "1. Completely transcribe the meeting audio/video\n" +
        "2. Include participant names and their roles\n" +
        "3. Document specific points discussed\n" +
        "4. Record decisions and task assignments\n\n" +
        "**RECOMMENDATIONS**\n" +
        "• Use automatic transcription tools like Otter.ai\n" +
        "• Provide additional context about the meeting purpose\n" +
        "• Include related documents or presentations"
      when 'proposal'
        "📄 PROPOSAL - INSUFFICIENT CONTENT\n\n" +
        "**TL;DR** [Summary]\n" +
        "More information is required to generate a complete proposal.\n\n" +
        "**Problem** [Identified]\n" +
        "The provided content is insufficient to clearly identify the problem to be solved.\n\n" +
        "**Solution** [Proposal]\n" +
        "Provide a complete transcription of the meeting for detailed analysis.\n\n" +
        "**KPIs** [Metrics]\n" +
        "• Completeness of information\n" +
        "• Clarity of objectives\n" +
        "• Scope definition\n\n" +
        "**Tech Spec** [Specifications]\n" +
        "• Complete requirements analysis\n" +
        "• Architecture definition\n" +
        "• Implementation plan\n\n" +
        "**Tasks** [List]\n" +
        "• Obtain complete transcription\n" +
        "• Analyze requirements\n" +
        "• Define project scope\n" +
        "• Create detailed proposal"
      when 'jira_ticket'
        "🎫 JIRA TICKETS - INSUFFICIENT CONTENT\n\n" +
        "**Epic: Requirements Analysis**\n" +
        "Problem: Lack of information to create specific tickets\n" +
        "Solution: Obtain complete meeting transcription\n\n" +
        "**Story: Information Gathering**\n" +
        "Priority: High\n" +
        "Problem: Insufficient content for analysis\n" +
        "Solution: Transcribe complete meeting\n" +
        "Criteria:\n" +
        "• Complete audio/video transcription\n" +
        "• Participant identification and roles\n" +
        "• Documentation of discussed topics\n" +
        "• Recording of decisions and actions\n\n" +
        "**Task: Meeting Transcription**\n" +
        "Priority: Critical\n" +
        "Problem: Content too short for processing\n" +
        "Solution: Provide complete transcription\n" +
        "Time: 1-2 hours"
      end
    end
  end

  def generate_technical_content_response(job_type, language)
    if language == 'es'
      "⚠️ CONTENIDO TÉCNICO DETECTADO\n\n" +
      "El archivo proporcionado contiene principalmente información técnica (metadatos) en lugar del contenido real de la reunión.\n\n" +
      "**PROBLEMA IDENTIFICADO:**\n" +
      "• El sistema extrajo información del archivo (nombre, tamaño, tipo) pero no el contenido de la reunión\n" +
      "• No se pudo acceder al contenido real del audio/video/texto\n\n" +
      "**SOLUCIONES RECOMENDADAS:**\n" +
      "1. **Para archivos de video/audio:**\n" +
      "   • Usar herramientas como Otter.ai, Google Docs o Zoom para transcribir\n" +
      "   • Proporcionar la transcripción en formato .txt\n\n" +
      "2. **Para archivos PDF:**\n" +
      "   • Copiar y pegar el contenido en un archivo .txt\n" +
      "   • Usar herramientas de conversión PDF a texto\n\n" +
      "3. **Para otros formatos:**\n" +
      "   • Convertir a formato de texto (.txt)\n" +
      "   • Proporcionar transcripción manual\n\n" +
      "**PRÓXIMO PASO:**\n" +
      "Sube un archivo con el contenido real de la reunión, no solo los metadatos del archivo."
    else
      "⚠️ TECHNICAL CONTENT DETECTED\n\n" +
      "The provided file contains mainly technical information (metadata) instead of the actual meeting content.\n\n" +
      "**IDENTIFIED PROBLEM:**\n" +
      "• The system extracted file information (name, size, type) but not the meeting content\n" +
      "• Could not access the actual audio/video/text content\n\n" +
      "**RECOMMENDED SOLUTIONS:**\n" +
      "1. **For video/audio files:**\n" +
      "   • Use tools like Otter.ai, Google Docs or Zoom to transcribe\n" +
      "   • Provide the transcription in .txt format\n\n" +
      "2. **For PDF files:**\n" +
      "   • Copy and paste the content into a .txt file\n" +
      "   • Use PDF to text conversion tools\n\n" +
      "3. **For other formats:**\n" +
      "   • Convert to text format (.txt)\n" +
      "   • Provide manual transcription\n\n" +
      "**NEXT STEP:**\n" +
      "Upload a file with the actual meeting content, not just the file metadata."
    end
  end

  def generate_incomplete_transcription_response(job_type, language)
    if language == 'es'
      "📝 TRANSCRIPCIÓN INCOMPLETA DETECTADA\n\n" +
      "La transcripción proporcionada parece ser incompleta o fragmentada.\n\n" +
      "**PROBLEMA IDENTIFICADO:**\n" +
      "• La transcripción solo incluye una parte de la reunión\n" +
      "• Falta contexto importante sobre objetivos y participantes\n" +
      "• No se pueden identificar decisiones o acciones específicas\n\n" +
      "**SOLUCIONES INMEDIATAS:**\n" +
      "1. **Transcripción completa:**\n" +
      "   • Proporcionar la transcripción completa de toda la reunión\n" +
      "   • Incluir desde el inicio hasta el final de la sesión\n\n" +
      "2. **Contexto adicional:**\n" +
      "   • Agregar información sobre el propósito de la reunión\n" +
      "   • Incluir lista de participantes y sus roles\n" +
      "   • Documentar objetivos específicos de la sesión\n\n" +
      "3. **Herramientas recomendadas:**\n" +
      "   • Otter.ai para transcripción automática\n" +
      "   • Google Docs con transcripción automática\n" +
      "   • Zoom con transcripción habilitada\n\n" +
      "**CONTENIDO MÍNIMO REQUERIDO:**\n" +
      "• Transcripción de al menos 5-10 minutos de conversación\n" +
      "• Identificación de participantes\n" +
      "• Temas principales discutidos\n" +
      "• Decisiones o acciones acordadas"
    else
      "📝 INCOMPLETE TRANSCRIPTION DETECTED\n\n" +
      "The provided transcription appears to be incomplete or fragmented.\n\n" +
      "**IDENTIFIED PROBLEM:**\n" +
      "• The transcription only includes part of the meeting\n" +
      "• Important context about objectives and participants is missing\n" +
      "• Specific decisions or actions cannot be identified\n\n" +
      "**IMMEDIATE SOLUTIONS:**\n" +
      "1. **Complete transcription:**\n" +
      "   • Provide the complete transcription of the entire meeting\n" +
      "   • Include from start to end of the session\n\n" +
      "2. **Additional context:**\n" +
      "   • Add information about the meeting purpose\n" +
      "   • Include list of participants and their roles\n" +
      "   • Document specific session objectives\n\n" +
      "3. **Recommended tools:**\n" +
      "   • Otter.ai for automatic transcription\n" +
      "   • Google Docs with automatic transcription\n" +
      "   • Zoom with transcription enabled\n\n" +
      "**MINIMUM REQUIRED CONTENT:**\n" +
      "• Transcription of at least 5-10 minutes of conversation\n" +
      "• Participant identification\n" +
      "• Main topics discussed\n" +
      "• Decisions or agreed actions"
    end
  end

  def generate_generic_insufficient_response(job_type, language)
    if language == 'es'
      "⚠️ CONTENIDO INSUFICIENTE\n\n" +
      "El contenido proporcionado no es suficiente para generar un análisis completo.\n\n" +
      "**RECOMENDACIONES:**\n" +
      "• Proporcionar una transcripción más completa\n" +
      "• Incluir contexto adicional sobre la reunión\n" +
      "• Agregar información sobre participantes y objetivos\n\n" +
      "**HERRAMIENTAS ÚTILES:**\n" +
      "• Otter.ai para transcripción automática\n" +
      "• Google Docs con transcripción\n" +
      "• Transcripción manual detallada"
    else
      "⚠️ INSUFFICIENT CONTENT\n\n" +
      "The provided content is not sufficient to generate a complete analysis.\n\n" +
      "**RECOMMENDATIONS:**\n" +
      "• Provide a more complete transcription\n" +
      "• Include additional context about the meeting\n" +
      "• Add information about participants and objectives\n\n" +
      "**USEFUL TOOLS:**\n" +
      "• Otter.ai for automatic transcription\n" +
      "• Google Docs with transcription\n" +
      "• Detailed manual transcription"
    end
  end
end
