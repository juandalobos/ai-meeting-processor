#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Cargar variables de entorno desde .env
if File.exist?('.env')
  File.readlines('.env').each do |line|
    next if line.start_with?('#') || line.strip.empty?
    key, value = line.strip.split('=', 2)
    ENV[key] = value if key && value
  end
end

# Cargar Rails para tener acceso a las constantes
require_relative 'config/environment'

puts "=== PRUEBA DE PROCESAMIENTO DE VIDEOS ==="
puts

# Configuración
base_url = "http://localhost:3001"

puts "1. Verificando que el servidor esté funcionando..."
begin
  response = Net::HTTP.get_response(URI("#{base_url}/api/health"))
  if response.code == "200"
    puts "✅ Servidor funcionando correctamente"
  else
    puts "❌ Servidor no responde correctamente"
    exit 1
  end
rescue => e
  puts "❌ Error conectando al servidor: #{e.message}"
  exit 1
end

puts
puts "2. Verificando que FFmpeg esté instalado..."
begin
  result = system('which ffmpeg > /dev/null 2>&1')
  if result
    puts "✅ FFmpeg está instalado"
    version = `ffmpeg -version | head -n1`.strip
    puts "   - Versión: #{version}"
  else
    puts "❌ FFmpeg no está instalado"
    puts "   - Ejecuta: ./setup_ffmpeg.sh"
    exit 1
  end
rescue => e
  puts "❌ Error verificando FFmpeg: #{e.message}"
  exit 1
end

puts
puts "3. Verificando variables de entorno..."
required_vars = ['OPENAI_API_KEY', 'GEMINI_API_KEY']
missing_vars = []

required_vars.each do |var|
  if ENV[var].nil? || ENV[var].empty?
    missing_vars << var
  else
    puts "✅ #{var} configurada"
  end
end

if missing_vars.any?
  puts "❌ Variables de entorno faltantes: #{missing_vars.join(', ')}"
  puts "   - Configura estas variables en tu archivo .env"
  exit 1
end

puts
puts "4. Verificando que el VideoProcessorService esté disponible..."
begin
  # Cargar el servicio
  load 'app/services/video_processor_service.rb'
  puts "✅ VideoProcessorService cargado correctamente"
rescue => e
  puts "❌ Error cargando VideoProcessorService: #{e.message}"
  exit 1
end

puts
puts "5. Verificando que el GeminiService tenga el método nuevo..."
begin
  # Cargar el servicio
  load 'app/services/gemini_service.rb'
  
  # Verificar que el método existe
  gemini_service = GeminiService.new
  if gemini_service.respond_to?(:process_meeting_content_from_text)
    puts "✅ Método process_meeting_content_from_text disponible"
  else
    puts "❌ Método process_meeting_content_from_text no encontrado"
    exit 1
  end
rescue => e
  puts "❌ Error verificando GeminiService: #{e.message}"
  exit 1
end

puts
puts "6. Verificando archivos de código..."
begin
  # Verificar que los archivos existen y tienen el método
  controller_file = File.read('app/controllers/api/meetings_controller.rb')
  job_file = File.read('app/jobs/process_meeting_job.rb')
  
  if controller_file.include?('def video_file?')
    puts "✅ Método video_file? presente en el controlador"
  else
    puts "❌ Método video_file? no encontrado en el controlador"
    exit 1
  end
  
  if job_file.include?('def video_file?')
    puts "✅ Método video_file? presente en ProcessMeetingJob"
  else
    puts "❌ Método video_file? no encontrado en ProcessMeetingJob"
    exit 1
  end
rescue => e
  puts "❌ Error verificando archivos: #{e.message}"
  exit 1
end

puts
puts "=== RESUMEN ==="
puts "✅ Servidor Rails funcionando"
puts "✅ FFmpeg instalado"
puts "✅ Variables de entorno configuradas"
puts "✅ VideoProcessorService disponible"
puts "✅ GeminiService actualizado"
puts "✅ Controlador actualizado"
puts "✅ Jobs actualizados"
puts
puts "🎉 ¡El procesamiento de videos está listo!"
puts
puts "Para probar el procesamiento de videos:"
puts "1. Ve a http://localhost:3000"
puts "2. Sube un archivo de video (MP4, AVI, MOV, etc.)"
puts "3. Haz clic en 'GENERAR PROPUESTA' o 'GENERAR RESUMEN EJECUTIVO'"
puts "4. El sistema:"
puts "   - Extraerá el audio del video con FFmpeg"
puts "   - Transcribirá el audio con Whisper"
puts "   - Procesará el contenido con Gemini"
puts
puts "Formatos de video soportados:"
puts "- MP4, AVI, MOV, WMV, FLV, WebM, MKV, M4V"
puts
puts "Requisitos:"
puts "- FFmpeg instalado (ya verificado)"
puts "- OPENAI_API_KEY configurada (ya verificado)"
puts "- GEMINI_API_KEY configurada (ya verificado)"
