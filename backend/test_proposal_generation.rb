#!/usr/bin/env ruby

require 'httparty'
require 'json'

# Configuración corregida
API_KEY = 'AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0'
BASE_URI = 'https://generativelanguage.googleapis.com/v1beta'
MODEL = 'gemini-1.5-flash'

puts "🧪 PROBANDO GENERACIÓN DE PROPUESTA TÉCNICA"
puts "=" * 60

# Contenido de prueba (simulando el contenido de una reunión)
test_content = """
REUNIÓN DE PROYECTO - 15 de Agosto 2024

Participantes: Juan, María, Carlos, Ana

Temas discutidos:
1. Desarrollo del nuevo sistema de gestión
2. Cronograma del proyecto
3. Asignación de responsabilidades

Decisiones tomadas:
- El proyecto debe completarse para el 30 de septiembre
- Juan será responsable del frontend
- María se encargará del backend
- Carlos coordinará las pruebas
- Ana manejará la documentación

Próximos pasos:
- Reunión semanal todos los lunes a las 10:00 AM
- Entrega de prototipo para el 20 de agosto
- Revisión de código el 25 de agosto

Riesgos identificados:
- Posible retraso en la entrega de APIs externas
- Falta de recursos de desarrollo
"""

# Prompt de la propuesta técnica (copiado del servicio)
prompt = <<~PROMPT
  Analiza el siguiente contenido de una reunión y genera una propuesta técnica detallada.
  
  CONTEXTO DEL NEGOCIO:
  No se proporcionó contexto específico del negocio.
  
  CONTENIDO DE LA REUNIÓN:
  #{test_content}
  
  INSTRUCCIONES:
  1. Identifica los requisitos técnicos mencionados
  2. Genera una propuesta técnica estructurada
  3. Usa SOLO información real del contenido
  4. NO inventes información que no esté presente
  
  ESTRUCTURA REQUERIDA:
  
  **RESUMEN EJECUTIVO**
  [Resumen de la propuesta técnica]
  
  **OBJETIVOS**
  [Objetivos identificados en la reunión]
  
  **REQUISITOS TÉCNICOS**
  [Requisitos técnicos mencionados]
  
  **ARQUITECTURA PROPUESTA**
  [Arquitectura o solución técnica propuesta]
  
  **CRONOGRAMA**
  [Cronograma mencionado o estimado]
  
  **RECURSOS NECESARIOS**
  [Recursos identificados en la reunión]
  
  **RIESGOS Y MITIGACIONES**
  [Riesgos mencionados y sus mitigaciones]
  
  IMPORTANTE: Si no hay información suficiente, indícalo claramente.
PROMPT

puts "📤 Enviando prompt de propuesta técnica a Gemini API..."
puts "Longitud del prompt: #{prompt.length} caracteres"
puts ""

begin
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
  
  puts "📊 Status Code: #{response.code}"
  
  if response.success?
    parsed_response = JSON.parse(response.body)
    if parsed_response['candidates']&.first&.dig('content', 'parts', 0, 'text')
      result = parsed_response['candidates'].first['content']['parts'][0]['text']
      puts "✅ ÉXITO - PROPUESTA TÉCNICA:"
      puts "=" * 60
      puts result
    else
      puts "❌ ERROR: No se pudo extraer el texto de la respuesta"
      puts "Respuesta completa: #{response.body}"
    end
  else
    puts "❌ ERROR: #{response.code} - #{response.body}"
  end
  
rescue => e
  puts "❌ EXCEPCIÓN: #{e.message}"
  puts e.backtrace.first(5)
end

puts ""
puts "🔍 ANÁLISIS DEL RESULTADO"
puts "=" * 60

if response&.success?
  result = JSON.parse(response.body)['candidates'].first['content']['parts'][0]['text']
  
  # Verificar si el resultado corresponde al contenido original
  puts "📋 Verificando correspondencia con el contenido original..."
  
  original_keywords = [
    "sistema de gestión",
    "Juan", "María", "Carlos", "Ana",
    "frontend", "backend", "pruebas", "documentación",
    "30 de septiembre", "20 de agosto", "25 de agosto",
    "APIs externas", "recursos de desarrollo"
  ]
  
  missing_keywords = []
  original_keywords.each do |keyword|
    unless result.downcase.include?(keyword.downcase)
      missing_keywords << keyword
    end
  end
  
  if missing_keywords.empty?
    puts "✅ El resultado incluye todos los elementos clave del contenido original"
  else
    puts "⚠️ El resultado NO incluye algunos elementos clave:"
    missing_keywords.each { |kw| puts "   - #{kw}" }
  end
  
  # Verificar estructura
  required_sections = [
    "RESUMEN EJECUTIVO",
    "OBJETIVOS", 
    "REQUISITOS TÉCNICOS",
    "ARQUITECTURA PROPUESTA",
    "CRONOGRAMA",
    "RECURSOS NECESARIOS",
    "RIESGOS Y MITIGACIONES"
  ]
  
  missing_sections = []
  required_sections.each do |section|
    unless result.include?(section)
      missing_sections << section
    end
  end
  
  if missing_sections.empty?
    puts "✅ El resultado incluye todas las secciones requeridas"
  else
    puts "⚠️ El resultado NO incluye algunas secciones requeridas:"
    missing_sections.each { |section| puts "   - #{section}" }
  end
end
