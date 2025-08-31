#!/usr/bin/env ruby

require 'httparty'
require 'json'

# Configuración
API_KEY = 'AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0'
BASE_URI = 'https://generativelanguage.googleapis.com/v1beta'
MODEL = 'gemini-1.5-flash'

puts "🧪 PROBANDO NUEVO FORMATO DE PROPUESTA EMPRESARIAL"
puts "=" * 60

# Contenido de prueba (simulando el contenido sobre Artemis)
test_content = """
REUNIÓN DE PROYECTO - Sistema de Preruteo Artemis

Participantes: Juan (PM), María (Tech Lead), Carlos (Desarrollador), Ana (Analista)

Temas discutidos:
1. Problema actual: Asignación manual de 300 órdenes diarias a técnicos
2. Proceso actual consume mucho tiempo y es propenso a errores
3. Necesidad de automatizar el preruteo de órdenes de trabajo
4. Integración con Metabase y Artemis

Problema identificado:
- Una sola persona maneja manualmente la asignación de órdenes
- Proceso actual usa scripts externos y hojas de cálculo
- No considera restricciones como disponibilidad de técnicos, zonas de trabajo, tipo de servicio
- Consume mucho tiempo y es ineficiente

Solución propuesta:
- Desarrollar sistema de preruteo integrado en Artemis
- Utilizar datos de Metabase para información de técnicos
- Considerar restricciones: disponibilidad, zonas, tipo de servicio, horarios
- Automatizar el proceso de asignación

Stakeholders identificados:
- Equipo de desarrollo de Artemis
- Usuario actual que maneja las asignaciones
- Técnicos que reciben las órdenes

Riesgos identificados:
- Posible retraso en la entrega de APIs externas
- Falta de recursos de desarrollo
- Resistencia al cambio del usuario actual

Cronograma:
- Prototipo: 20 de agosto
- Revisión de código: 25 de agosto
- Finalización: 30 de septiembre
"""

# Nuevo prompt de propuesta empresarial
prompt = <<~PROMPT
  Analiza el siguiente contenido de una reunión y genera una propuesta técnica siguiendo el formato empresarial estándar.
  
  CONTEXTO DEL NEGOCIO:
  No se proporcionó contexto específico del negocio.
  
  CONTENIDO DE LA REUNIÓN:
  #{test_content}
  
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

puts "📤 Enviando prompt con nuevo formato empresarial..."
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
      puts "✅ ÉXITO - NUEVA PROPUESTA EMPRESARIAL:"
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
puts "🔍 VERIFICACIÓN DEL FORMATO"
puts "=" * 60

if response&.success?
  result = JSON.parse(response.body)['candidates'].first['content']['parts'][0]['text']
  
  # Verificar secciones del nuevo formato
  required_sections = [
    "TL;DR",
    "Problem",
    "What's not covered by this proposal?",
    "Product Spec",
    "Stakeholders",
    "User Stories",
    "Proposed Solution",
    "Target value (result)",
    "Existing Solutions",
    "KPIs",
    "Risks & Mitigation",
    "Tech Spec",
    "Tasks"
  ]
  
  missing_sections = []
  present_sections = []
  
  required_sections.each do |section|
    if result.include?(section)
      present_sections << section
    else
      missing_sections << section
    end
  end
  
  puts "✅ Secciones presentes (#{present_sections.length}/#{required_sections.length}):"
  present_sections.each { |section| puts "  ✅ #{section}" }
  
  if missing_sections.any?
    puts ""
    puts "⚠️ Secciones faltantes:"
    missing_sections.each { |section| puts "  ❌ #{section}" }
  else
    puts ""
    puts "🎉 ¡Todas las secciones están presentes!"
  end
  
  # Verificar que no tiene el formato anterior
  old_sections = [
    "RESUMEN EJECUTIVO",
    "OBJETIVOS",
    "REQUISITOS TÉCNICOS",
    "ARQUITECTURA PROPUESTA"
  ]
  
  old_sections_found = []
  old_sections.each do |section|
    if result.include?(section)
      old_sections_found << section
    end
  end
  
  if old_sections_found.any?
    puts ""
    puts "⚠️ Se encontraron secciones del formato anterior:"
    old_sections_found.each { |section| puts "  ⚠️ #{section}" }
  else
    puts ""
    puts "✅ No se encontraron secciones del formato anterior"
  end
end
