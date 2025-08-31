#!/usr/bin/env ruby

require 'httparty'
require 'json'

# Configuración de la API de Gemini (versión corregida)
API_KEY = 'AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0'
BASE_URI = 'https://generativelanguage.googleapis.com/v1beta'
MODEL = 'gemini-1.5-flash'  # Sin el prefijo 'models/'

puts "🧪 PROBANDO API DE GEMINI (VERSIÓN CORREGIDA)"
puts "=" * 60

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
  puts "📄 Response Body: #{response.body[0..300]}..."
  
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
puts "🔍 PROBANDO DIFERENTES MODELOS"
puts "=" * 60

# Probar diferentes modelos
models_to_test = [
  'gemini-1.5-flash',
  'gemini-1.5-pro',
  'gemini-pro',
  'gemini-1.0-pro'
]

models_to_test.each do |model|
  puts "🧪 Probando modelo: #{model}"
  
  begin
    response = HTTParty.post(
      "#{BASE_URI}/models/#{model}:generateContent?key=#{API_KEY}",
      headers: {
        'Content-Type' => 'application/json'
      },
      body: {
        contents: [{
          parts: [{
            text: "Hola"
          }]
        }]
      }.to_json
    )
    
    if response.success?
      puts "✅ #{model}: FUNCIONA"
    else
      puts "❌ #{model}: #{response.code}"
    end
    
  rescue => e
    puts "❌ #{model}: ERROR - #{e.message}"
  end
end

puts ""
puts "📋 LISTA DE MODELOS DISPONIBLES"
puts "=" * 60

begin
  models_response = HTTParty.get("https://generativelanguage.googleapis.com/v1beta/models?key=#{API_KEY}")
  if models_response.success?
    models = JSON.parse(models_response.body)
    if models['models']
      models['models'].each do |model|
        puts "📋 #{model['name']} - #{model['description']}"
      end
    else
      puts "❌ No se pudieron obtener los modelos"
    end
  else
    puts "❌ Error obteniendo modelos: #{models_response.code}"
  end
rescue => e
  puts "❌ Error: #{e.message}"
end
