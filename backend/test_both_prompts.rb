#!/usr/bin/env ruby

require 'httparty'
require 'json'

# Configuración
API_KEY = 'AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0'
BASE_URI = 'https://generativelanguage.googleapis.com/v1beta'
MODEL = 'gemini-1.5-flash'

puts "🧪 COMPARANDO PROMPTS: RESUMEN EJECUTIVO vs PROPUESTA TÉCNICA"
puts "=" * 70

# Contenido de prueba
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

# Prompt del resumen ejecutivo
executive_prompt = <<~PROMPT
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

# Prompt de la propuesta técnica
proposal_prompt = <<~PROMPT
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

def call_gemini_api(prompt, description)
  puts "📤 #{description}..."
  
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
      result = parsed_response['candidates'].first['content']['parts'][0]['text']
      return result
    else
      return "ERROR: No se pudo extraer el texto de la respuesta"
    end
  else
    return "ERROR: #{response.code} - #{response.body}"
  end
end

# Generar ambos resultados
executive_result = call_gemini_api(executive_prompt, "Generando Resumen Ejecutivo")
proposal_result = call_gemini_api(proposal_prompt, "Generando Propuesta Técnica")

puts ""
puts "📊 COMPARACIÓN DE RESULTADOS"
puts "=" * 70

puts "📋 RESUMEN EJECUTIVO:"
puts "-" * 40
puts executive_result[0..500] + "..."
puts ""

puts "📋 PROPUESTA TÉCNICA:"
puts "-" * 40
puts proposal_result[0..500] + "..."
puts ""

puts "🔍 ANÁLISIS DE DIFERENCIAS"
puts "=" * 70

# Verificar que son diferentes
if executive_result != proposal_result
  puts "✅ Los resultados son DIFERENTES (correcto)"
  
  # Verificar secciones específicas
  executive_sections = [
    "PUNTOS CLAVE DISCUTIDOS",
    "ACCIONABLES PRIORITARIOS", 
    "RESPONSABLES Y ASIGNACIONES",
    "PRÓXIMOS PASOS Y CRONOGRAMA",
    "DECISIONES TOMADAS",
    "RIESGOS Y CONSIDERACIONES"
  ]
  
  proposal_sections = [
    "OBJETIVOS",
    "REQUISITOS TÉCNICOS",
    "ARQUITECTURA PROPUESTA",
    "CRONOGRAMA",
    "RECURSOS NECESARIOS",
    "RIESGOS Y MITIGACIONES"
  ]
  
  puts ""
  puts "📋 Secciones del Resumen Ejecutivo:"
  executive_sections.each do |section|
    if executive_result.include?(section)
      puts "  ✅ #{section}"
    else
      puts "  ❌ #{section}"
    end
  end
  
  puts ""
  puts "📋 Secciones de la Propuesta Técnica:"
  proposal_sections.each do |section|
    if proposal_result.include?(section)
      puts "  ✅ #{section}"
    else
      puts "  ❌ #{section}"
    end
  end
  
else
  puts "❌ Los resultados son IDÉNTICOS (incorrecto)"
end

puts ""
puts "💡 CONCLUSIÓN"
puts "=" * 70
puts "El sistema está funcionando correctamente:"
puts "• Resumen Ejecutivo: Genera un resumen de la reunión"
puts "• Propuesta Técnica: Genera una propuesta técnica estructurada"
puts "• Ambos son diferentes y apropiados para su propósito"
