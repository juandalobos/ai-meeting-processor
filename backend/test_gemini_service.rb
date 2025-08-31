#!/usr/bin/env ruby

# Cargar el entorno de Rails
require_relative 'config/environment'

puts "🧪 PROBANDO GEMINI SERVICE CORREGIDO"
puts "=" * 50

# Crear una instancia del servicio
gemini_service = GeminiService.new

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

puts "📝 Contenido de prueba:"
puts test_content[0..200] + "..."
puts ""

begin
  puts "🔄 Procesando con Gemini Service..."
  result = gemini_service.process_meeting_content(
    OpenStruct.new(id: 1, title: "Reunión de Prueba"),
    'executive_summary',
    nil,
    'es'
  )
  
  puts "✅ RESULTADO:"
  puts "=" * 50
  puts result
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(5)
end
