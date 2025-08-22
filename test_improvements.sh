#!/bin/bash

echo "🧪 PROBANDO MEJORAS EN EL SISTEMA DE IA"
echo "========================================"

# Función para probar el procesamiento
test_processing() {
    local file_path=$1
    local job_type=$2
    local description=$3
    
    echo ""
    echo "📋 Probando: $description"
    echo "Archivo: $file_path"
    echo "Tipo: $job_type"
    echo "----------------------------------------"
    
    # Crear meeting con el archivo
    response=$(curl -s -X POST http://localhost:3001/api/meetings \
        -F "meeting[title]=Test Meeting - $description" \
        -F "meeting[file]=@$file_path")
    
    meeting_id=$(echo $response | grep -o '"id":[0-9]*' | cut -d':' -f2)
    
    if [ -z "$meeting_id" ]; then
        echo "❌ Error creando meeting"
        return
    fi
    
    echo "✅ Meeting creado con ID: $meeting_id"
    
    # Procesar contenido
    echo "🔄 Procesando contenido..."
    processing_response=$(curl -s -X POST "http://localhost:3001/api/meetings/$meeting_id/process_content" \
        -H "Content-Type: application/json" \
        -d "{\"job_type\":\"$job_type\",\"language\":\"es\",\"sync\":\"true\"}")
    
    # Extraer resultado
    result=$(echo $processing_response | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$result" ]; then
        echo "✅ Procesamiento completado"
        echo "📄 Resultado (primeras 200 caracteres):"
        echo "${result:0:200}..."
        echo ""
    else
        echo "❌ Error en el procesamiento"
        echo "Respuesta: $processing_response"
    fi
}

echo ""
echo "🚀 INICIANDO PRUEBAS..."
echo ""

# Prueba 1: Contenido completo (debería funcionar bien)
test_processing "test_meeting_content.txt" "executive_summary" "Contenido Completo - Resumen Ejecutivo"

# Prueba 2: Contenido muy corto (debería detectar contenido insuficiente)
echo "📝 Creando archivo con contenido muy corto..."
echo "Reunión corta sobre appointments." > short_content.txt
test_processing "short_content.txt" "executive_summary" "Contenido Muy Corto - Debería Detectar Insuficiente"

# Prueba 3: Contenido técnico (debería detectar metadatos)
echo "📝 Creando archivo con información técnica..."
cat > technical_content.txt << EOF
Archivo de video: meeting_recording.mp4
Duración: 45.2 segundos
Resolución: 1920x1080
Audio: Sí detectado
File size: 15.2 MB
Content-Type: video/mp4
EOF
test_processing "technical_content.txt" "executive_summary" "Contenido Técnico - Debería Detectar Metadatos"

# Prueba 4: Propuesta con contenido completo
test_processing "test_meeting_content.txt" "proposal" "Contenido Completo - Propuesta Técnica"

# Prueba 5: Tickets Jira con contenido completo
test_processing "test_meeting_content.txt" "jira_ticket" "Contenido Completo - Tickets Jira"

echo ""
echo "🎉 PRUEBAS COMPLETADAS"
echo "======================"
echo ""
echo "📊 RESUMEN DE MEJORAS IMPLEMENTADAS:"
echo "✅ Validación de contenido antes del procesamiento"
echo "✅ Detección de contenido insuficiente"
echo "✅ Detección de metadatos técnicos"
echo "✅ Respuestas específicas para cada tipo de problema"
echo "✅ Prompts mejorados para mejor análisis"
echo "✅ Manejo de casos edge y errores"
echo ""
echo "🌐 Para probar manualmente, visita:"
echo "   Frontend: http://localhost:3000"
echo "   Backend API: http://localhost:3001/api"
echo ""
echo "📁 Archivos de prueba creados:"
echo "   - test_meeting_content.txt (contenido completo)"
echo "   - short_content.txt (contenido muy corto)"
echo "   - technical_content.txt (metadatos técnicos)"
