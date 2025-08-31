#!/usr/bin/env ruby

require 'httparty'
require 'json'

# Configuración
API_KEY = 'AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0'
BASE_URI = 'https://generativelanguage.googleapis.com/v1beta'
MODEL = 'gemini-1.5-flash'

puts "🧪 PROBANDO FUNCIONALIDAD DE TRADUCCIÓN"
puts "=" * 50

# Contenido en español para traducir
spanish_content = """
**RESUMEN EJECUTIVO**

La reunión de proyecto del 15 de agosto de 2024, a la que asistieron Juan, María, Carlos y Ana, se centró en el desarrollo de un nuevo sistema de gestión. Se establecieron plazos, responsabilidades y próximos pasos para asegurar la finalización del proyecto.

**PUNTOS CLAVE DISCUTIDOS**

• Desarrollo del nuevo sistema de gestión.
• Cronograma del proyecto.
• Asignación de responsabilidades.

**ACCIONABLES PRIORITARIOS**

• Entrega de prototipo para el 20 de agosto (Responsable: No especificado explícitamente).
• Revisión de código el 25 de agosto (Responsable: No especificado explícitamente).

**RESPONSABLES Y ASIGNACIONES**

• Juan: Frontend.
• María: Backend.
• Carlos: Coordinación de pruebas.
• Ana: Documentación.
"""

# Función para detectar idioma
def detect_language(content)
  spanish_indicators = ['el', 'la', 'de', 'que', 'y', 'en', 'un', 'es', 'se', 'no', 'te', 'lo', 'le', 'da', 'su', 'por', 'son', 'con', 'para', 'al', 'del', 'los', 'las', 'una', 'como', 'más', 'pero', 'sus', 'me', 'hasta', 'hay', 'donde', 'han', 'quien', 'están', 'estado', 'desde', 'todo', 'nos', 'durante', 'todos', 'uno', 'les', 'ni', 'contra', 'otros', 'ese', 'eso', 'ante', 'ellos', 'e', 'esto', 'mí', 'antes', 'algunos', 'qué', 'unos', 'yo', 'otro', 'otras', 'otra', 'él', 'tanto', 'esa', 'estos', 'mucho', 'quienes', 'nada', 'muchos', 'cual', 'poco', 'ella', 'estar', 'estas', 'algunas', 'algo', 'nosotros']
  english_indicators = ['the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i', 'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at', 'this', 'but', 'his', 'by', 'from', 'they', 'we', 'say', 'her', 'she', 'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their', 'what', 'so', 'up', 'out', 'if', 'about', 'who', 'get', 'which', 'go', 'me', 'when', 'make', 'can', 'like', 'time', 'no', 'just', 'him', 'know', 'take', 'people', 'into', 'year', 'your', 'good', 'some', 'could', 'them', 'see', 'other', 'than', 'then', 'now', 'look', 'only', 'come', 'its', 'over', 'think', 'also', 'back', 'after', 'use', 'two', 'how', 'our', 'work', 'first', 'well', 'way', 'even', 'new', 'want', 'because', 'any', 'these', 'give', 'day', 'most', 'us']
  
  spanish_count = spanish_indicators.count { |word| content.downcase.include?(word) }
  english_count = english_indicators.count { |word| content.downcase.include?(word) }
  
  if spanish_count > english_count
    'es'
  else
    'en'
  end
end

# Función para crear prompt de traducción
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

# Función para llamar a la API de Gemini
def call_gemini_api(prompt)
  response = HTTParty.post(
    "#{BASE_URI}/models/#{MODEL}:generateContent?key=#{API_KEY}",
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
  )
  
  if response.success?
    parsed_response = JSON.parse(response.body)
    if parsed_response['candidates']&.first&.dig('content', 'parts', 0, 'text')
      parsed_response['candidates'].first['content']['parts'][0]['text']
    else
      "ERROR: No se pudo extraer el texto de la respuesta"
    end
  else
    "ERROR: #{response.code} - #{response.body}"
  end
end

puts "📝 Contenido original (Español):"
puts spanish_content[0..200] + "..."
puts ""

# Detectar idioma
detected_language = detect_language(spanish_content)
puts "🔍 Idioma detectado: #{detected_language}"
puts ""

# Traducir a inglés
puts "🔄 Traduciendo a inglés..."
translation_prompt = build_translation_prompt(spanish_content, 'es', 'en')
translated_content = call_gemini_api(translation_prompt)

puts "✅ Traducción completada:"
puts "=" * 50
puts translated_content
puts ""

# Verificar que la traducción es diferente
if translated_content != spanish_content && !translated_content.start_with?("ERROR")
  puts "✅ La traducción es diferente al contenido original"
  
  # Verificar que contiene palabras en inglés
  english_words = ['the', 'and', 'of', 'to', 'in', 'that', 'have', 'with', 'for', 'this']
  english_word_count = english_words.count { |word| translated_content.downcase.include?(word) }
  
  if english_word_count > 5
    puts "✅ La traducción contiene palabras en inglés"
  else
    puts "⚠️ La traducción no parece contener suficientes palabras en inglés"
  end
  
  # Verificar que mantiene la estructura
  if translated_content.include?("**") && translated_content.include?("•")
    puts "✅ La traducción mantiene la estructura (headers y viñetas)"
  else
    puts "⚠️ La traducción no mantiene la estructura original"
  end
  
else
  puts "❌ Error en la traducción o no se detectó cambio"
end

puts ""
puts "🔄 Traduciendo de vuelta a español..."
back_translation_prompt = build_translation_prompt(translated_content, 'en', 'es')
back_translated_content = call_gemini_api(back_translation_prompt)

puts "✅ Traducción de vuelta completada:"
puts "=" * 50
puts back_translated_content[0..300] + "..."
puts ""

puts "🔍 RESUMEN DE PRUEBAS"
puts "=" * 50
puts "• Detección de idioma: #{detected_language == 'es' ? '✅ Correcta' : '❌ Incorrecta'}"
puts "• Traducción a inglés: #{translated_content.start_with?('ERROR') ? '❌ Falló' : '✅ Exitosa'}"
puts "• Traducción de vuelta: #{back_translated_content.start_with?('ERROR') ? '❌ Falló' : '✅ Exitosa'}"
puts "• Funcionalidad general: #{translated_content.start_with?('ERROR') ? '❌ No funciona' : '✅ Funciona correctamente'}"
