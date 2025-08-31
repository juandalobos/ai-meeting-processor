#!/usr/bin/env ruby

require 'httparty'
require 'json'

# Configuración de la API de Gemini
API_KEY = 'AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0'
BASE_URI = 'https://generativelanguage.googleapis.com/v1beta'
MODEL = 'models/gemini-1.5-flash'

puts "🧪 PROBANDO API DE GEMINI"
puts "=" * 50

# Test simple
test_prompt = "Responde con 'OK' si puedes leer este mensaje."

puts "📤 Enviando prompt de prueba..."
puts "Prompt: #{test_prompt}"

begin
  response = HTTParty.post(
    "#{BASE_URI}/models/#{MODEL}:generateContent?key=#{API_KEY}",
    headers: {
      'Content-Type' => 'application/json'
    },
    body: {
      contents: [{
        parts: [{
          text: test_prompt
        }]
      }]
    }.to_json
  )
  
  puts "📊 Status Code: #{response.code}"
  puts "📄 Response Body: #{response.body[0..200]}..."
  
  if response.success?
    parsed_response = JSON.parse(response.body)
    if parsed_response['candidates']&.first&.dig('content', 'parts', 0, 'text')
      result = parsed_response['candidates'].first['content']['parts'][0]['text']
      puts "✅ ÉXITO: #{result}"
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
puts "🔍 DIAGNÓSTICO COMPLETO"
puts "=" * 50

# Verificar conectividad
puts "🌐 Probando conectividad a Google APIs..."
begin
  test_response = HTTParty.get("https://generativelanguage.googleapis.com/v1beta/models?key=#{API_KEY}")
  puts "✅ Conectividad: OK (Status: #{test_response.code})"
rescue => e
  puts "❌ Conectividad: FALLA - #{e.message}"
end

# Verificar API key
puts "🔑 Verificando API key..."
begin
  models_response = HTTParty.get("https://generativelanguage.googleapis.com/v1beta/models?key=#{API_KEY}")
  if models_response.success?
    puts "✅ API Key: VÁLIDA"
  else
    puts "❌ API Key: INVÁLIDA - #{models_response.code}"
  end
rescue => e
  puts "❌ API Key: ERROR - #{e.message}"
end

puts ""
puts "📋 RECOMENDACIONES:"
puts "=" * 50

if response&.success?
  puts "✅ La API de Gemini está funcionando correctamente"
  puts "🔧 El problema puede estar en el procesamiento del contenido"
else
  puts "❌ La API de Gemini no está funcionando"
  puts "🔧 Posibles soluciones:"
  puts "   1. Verificar la API key"
  puts "   2. Verificar la conectividad a internet"
  puts "   3. Verificar las cuotas de la API"
  puts "   4. Probar con una API key diferente"
end
