#!/bin/bash

echo "🧪 PROBANDO ARCHIVO REAL DEL USUARIO"
echo "===================================="

echo ""
echo "📋 INSTRUCCIONES:"
echo "1. Coloca tu archivo de transcripción en esta carpeta"
echo "2. Ejecuta este script con: ./test_user_file.sh TU_ARCHIVO.txt"
echo "3. El sistema procesará tu archivo con las mejoras implementadas"
echo ""

if [ $# -eq 0 ]; then
    echo "❌ Error: Debes especificar el archivo a procesar"
    echo "Uso: ./test_user_file.sh archivo_transcripcion.txt"
    echo ""
    echo "📁 Archivos disponibles en esta carpeta:"
    ls -la *.txt 2>/dev/null || echo "No hay archivos .txt en esta carpeta"
    exit 1
fi

file_path=$1

if [ ! -f "$file_path" ]; then
    echo "❌ Error: El archivo '$file_path' no existe"
    exit 1
fi

echo "📄 Procesando archivo: $file_path"
echo "📊 Tamaño: $(wc -c < "$file_path") caracteres"
echo "📝 Primeras líneas del archivo:"
head -5 "$file_path"
echo "..."

# Crear meeting con el archivo del usuario
echo ""
echo "🔄 Creando meeting con tu archivo..."
response=$(curl -s -X POST http://localhost:3001/api/meetings \
    -F "meeting[title]=Mi Reunión - $(basename "$file_path")" \
    -F "meeting[file]=@$file_path")

meeting_id=$(echo $response | grep -o '"id":[0-9]*' | cut -d':' -f2)

if [ -z "$meeting_id" ]; then
    echo "❌ Error creando meeting"
    echo "Respuesta: $response"
    exit 1
fi

echo "✅ Meeting creado con ID: $meeting_id"

# Procesar contenido
echo "🔄 Procesando contenido con IA mejorada..."
processing_response=$(curl -s -X POST "http://localhost:3001/api/meetings/$meeting_id/process_content" \
    -H "Content-Type: application/json" \
    -d "{\"job_type\":\"executive_summary\",\"language\":\"es\",\"sync\":\"true\"}")

# Extraer resultado
result=$(echo $processing_response | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -n "$result" ]; then
    echo "✅ Procesamiento completado exitosamente!"
    echo ""
    echo "📄 RESULTADO COMPLETO:"
    echo "======================"
    echo "$result"
    echo ""
    echo "📊 Estadísticas:"
    echo "  - Longitud del archivo original: $(wc -c < "$file_path") caracteres"
    echo "  - Longitud del resultado: ${#result} caracteres"
    echo "  - Meeting ID: $meeting_id"
    echo ""
    echo "🌐 Para ver el resultado en la interfaz web: http://localhost:3000"
    echo "🔗 URL directa del meeting: http://localhost:3001/api/meetings/$meeting_id"
    
    # Verificar si contiene mensajes de error
    if echo "$result" | grep -q "insuficiente\|falta de información\|no se puede\|no se identifican"; then
        echo ""
        echo "⚠️  ADVERTENCIA: El resultado aún contiene mensajes de insuficiencia"
        echo "   Esto puede indicar que el archivo necesita más contenido o mejor formato"
    else
        echo ""
        echo "🎉 ÉXITO: El resultado no contiene mensajes de insuficiencia"
        echo "   El sistema procesó tu archivo correctamente"
    fi
else
    echo "❌ Error en el procesamiento"
    echo "Respuesta: $processing_response"
fi


