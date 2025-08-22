#!/usr/bin/env ruby

# Debug script para verificar la lectura de archivos
require 'bundler/setup'
require_relative 'backend/config/environment'

puts "🔍 DEBUG: Verificando lectura de archivos"
puts "=" * 50

# Verificar meeting 8
meeting = Meeting.find(8)
puts "Meeting ID: #{meeting.id}"
puts "Título: #{meeting.title}"
puts "Archivo adjunto: #{meeting.file.attached?}"

if meeting.file.attached?
  puts "Nombre del archivo: #{meeting.file.filename}"
  puts "Tipo de contenido: #{meeting.file.content_type}"
  puts "Tamaño: #{meeting.file.byte_size} bytes"
  
  # Intentar leer el contenido
  begin
    content = meeting.file.download.force_encoding('UTF-8')
    puts "Contenido extraído: #{content.length} caracteres"
    puts "Primeros 200 caracteres:"
    puts content[0..200]
    puts "..." if content.length > 200
  rescue => e
    puts "Error leyendo archivo: #{e.message}"
  end
else
  puts "❌ NO HAY ARCHIVO ADJUNTO"
  
  # Verificar si hay attachments en la base de datos
  attachments = ActiveStorage::Attachment.where(record: meeting)
  puts "Attachments en DB: #{attachments.count}"
  attachments.each do |att|
    puts "  - #{att.name}: #{att.blob.filename}"
  end
end

puts "\n" + "=" * 50
puts "Verificando processing jobs:"
meeting.processing_jobs.each do |job|
  puts "Job ID: #{job.id}"
  puts "Tipo: #{job.job_type}"
  puts "Estado: #{job.status}"
  puts "Resultado (primeros 200 chars): #{job.result[0..200] if job.result}"
  puts "---"
end

puts "\n" + "=" * 50
puts "Probando con archivo de prueba:"

# Crear un meeting de prueba con el archivo de prueba
test_file_path = File.join(Dir.pwd, 'test_meeting_content.txt')
if File.exist?(test_file_path)
  puts "Archivo de prueba encontrado: #{test_file_path}"
  
  # Crear meeting de prueba
  test_meeting = Meeting.new(title: "Test Debug Meeting")
  test_meeting.file.attach(
    io: File.open(test_file_path),
    filename: 'test_meeting_content.txt',
    content_type: 'text/plain'
  )
  
  if test_meeting.save
    puts "✅ Meeting de prueba creado con ID: #{test_meeting.id}"
    puts "Archivo adjunto: #{test_meeting.file.attached?}"
    
    if test_meeting.file.attached?
      content = test_meeting.file.download.force_encoding('UTF-8')
      puts "Contenido leído: #{content.length} caracteres"
      puts "Primeros 200 caracteres:"
      puts content[0..200]
      
      # Probar el servicio de Gemini
      puts "\nProbando GeminiService..."
      gemini_service = GeminiService.new
      result = gemini_service.process_meeting_content(test_meeting, 'executive_summary', nil, 'es')
      puts "Resultado del procesamiento:"
      puts result[0..500]
    end
  else
    puts "❌ Error creando meeting de prueba: #{test_meeting.errors.full_messages}"
  end
else
  puts "❌ Archivo de prueba no encontrado: #{test_file_path}"
end
