#!/usr/bin/env ruby

require 'httparty'
require 'json'

# Configuración corregida
API_KEY = 'AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0'
BASE_URI = 'https://generativelanguage.googleapis.com/v1beta'
MODEL = 'gemini-1.5-flash'

puts "🧪 PROBANDO PROCESAMIENTO DE REUNIÓN"
puts "=" * 50

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

# Prompt del resumen ejecutivo (copiado del servicio)
prompt = <<~PROMPT
  Analiza el siguiente contenido de una reunión y genera un resumen ejecutivo completo y detallado.
  
  CONTEXTO DEL NEGOCIO:
  No se proporcionó contexto específico del negocio.
  
  CONTENIDO DE LA REUNIÓN:
  #{test_content}
  
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

puts "📤 Enviando prompt a Gemini API..."
puts "Longitud del prompt: #{prompt.length} caracteres"

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
      puts "✅ ÉXITO - RESULTADO:"
      puts "=" * 50
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
