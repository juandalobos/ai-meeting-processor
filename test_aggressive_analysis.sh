#!/bin/bash

echo "🧪 PROBANDO ANÁLISIS AGRESIVO DE CONTENIDO"
echo "==========================================="

# Crear diferentes tipos de archivos para probar
echo "📝 Creando archivos de prueba..."

# Archivo con contenido mínimo pero válido
cat > minimal_content.txt << 'EOF'
Reunión de equipo.
Participantes: Juan, María.
Tema: Proyecto nuevo.
Decisión: Comenzar mañana.
EOF

# Archivo con contenido técnico pero con información útil
cat > technical_with_content.txt << 'EOF'
Archivo de video: reunion_equipo.mp4
Duración: 45 minutos
Resolución: 1920x1080
Audio: Estéreo

TRANSCRIPCIÓN:
Juan: Buenos días equipo, tenemos que revisar el proyecto de la aplicación móvil.
María: Sí, necesitamos definir las funcionalidades principales.
Juan: Propongo que empecemos con el login y el dashboard.
María: De acuerdo, podemos tenerlo listo para la próxima semana.
Juan: Perfecto, entonces María se encarga del frontend y yo del backend.
María: Sí, empezaré mañana mismo.
EOF

# Archivo con contenido que antes sería rechazado
cat > short_but_meaningful.txt << 'EOF'
Reunión de planificación.
Objetivo: Definir estrategia Q4.
Participantes: Ana, Carlos, Luis.
Decisión: Lanzar producto en octubre.
Responsable: Ana.
Timeline: 3 meses.
EOF

echo "✅ Archivos de prueba creados"

# Función para probar un archivo
test_file() {
    local file_path=$1
    local description=$2
    
    echo ""
    echo "🔄 Probando: $description"
    echo "📊 Tamaño: $(wc -c < $file_path) caracteres"
    
    # Crear meeting
    response=$(curl -s -X POST http://localhost:3001/api/meetings \
        -F "meeting[title]=Test - $description" \
        -F "meeting[file]=@$file_path")
    
    meeting_id=$(echo $response | grep -o '"id":[0-9]*' | cut -d':' -f2)
    
    if [ -z "$meeting_id" ]; then
        echo "❌ Error creando meeting"
        return
    fi
    
    echo "✅ Meeting creado con ID: $meeting_id"
    
    # Procesar contenido
    processing_response=$(curl -s -X POST "http://localhost:3001/api/meetings/$meeting_id/process_content" \
        -H "Content-Type: application/json" \
        -d "{\"job_type\":\"executive_summary\",\"language\":\"es\",\"sync\":\"true\"}")
    
    # Extraer resultado
    result=$(echo $processing_response | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$result" ]; then
        echo "✅ Procesamiento completado"
        echo "📄 Resultado (primeras 300 caracteres):"
        echo "${result:0:300}..."
        echo ""
        echo "📊 Longitud del resultado: ${#result} caracteres"
        
        # Verificar si contiene mensajes de error
        if echo "$result" | grep -q "insuficiente\|falta de información\|no se puede\|no se identifican"; then
            echo "⚠️  ADVERTENCIA: El resultado contiene mensajes de insuficiencia"
        else
            echo "✅ ÉXITO: El resultado no contiene mensajes de insuficiencia"
        fi
    else
        echo "❌ Error en el procesamiento"
        echo "Respuesta: $processing_response"
    fi
}

# Probar diferentes tipos de contenido
test_file "minimal_content.txt" "Contenido Mínimo"
test_file "technical_with_content.txt" "Técnico con Contenido"
test_file "short_but_meaningful.txt" "Corto pero Significativo"

echo ""
echo "🎉 Pruebas completadas"
echo "====================="
echo "📁 Archivos de prueba creados:"
echo "  - minimal_content.txt"
echo "  - technical_with_content.txt"
echo "  - short_but_meaningful.txt"
echo "🌐 Para ver resultados completos, visita: http://localhost:3000"


