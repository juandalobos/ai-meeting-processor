#!/bin/bash

echo "🚀 CONFIGURACIÓN RÁPIDA - AI MEETING PROCESSOR"
echo "=============================================="
echo ""

# Verificar si existe el archivo .env
if [ ! -f .env ]; then
    echo "📝 Creando archivo .env..."
    cp env.example .env
    echo "✅ Archivo .env creado"
else
    echo "✅ Archivo .env ya existe"
fi

echo ""
echo "🔧 CONFIGURACIÓN DE API KEYS"
echo "============================"
echo ""

echo "Para que la aplicación funcione completamente, necesitas configurar al menos una API key:"
echo ""

echo "1️⃣  OPENAI API (RECOMENDADO - Más fácil)"
echo "   • Ve a: https://platform.openai.com/api-keys"
echo "   • Crea una cuenta gratuita"
echo "   • Genera una API key"
echo "   • Copia la key y agrégalo al archivo .env"
echo ""

echo "2️⃣  ASSEMBLYAI (GRATUITO - 3 horas/mes)"
echo "   • Ve a: https://www.assemblyai.com/"
echo "   • Crea una cuenta gratuita"
echo "   • Obtén tu API key"
echo "   • Agrégalo al archivo .env"
echo ""

echo "3️⃣  GEMINI API (Para procesamiento de contenido)"
echo "   • Ve a: https://makersuite.google.com/app/apikey"
echo "   • Crea una API key"
echo "   • Agrégalo al archivo .env"
echo ""

echo "📝 EJEMPLO DE CONFIGURACIÓN:"
echo "============================"
echo ""
echo "Edita el archivo .env y agrega tus API keys:"
echo ""
echo "OPENAI_API_KEY=sk-tu_api_key_aqui"
echo "ASSEMBLY_AI_KEY=tu_assembly_ai_key_aqui"
echo "GEMINI_API_KEY=tu_gemini_api_key_aqui"
echo ""

echo "🔍 VERIFICACIÓN DE HERRAMIENTAS"
echo "==============================="
echo ""

# Verificar ffmpeg
if command -v ffmpeg &> /dev/null; then
    echo "✅ ffmpeg está instalado"
else
    echo "❌ ffmpeg no está instalado"
    echo "   Instala ffmpeg para procesamiento local de audio/video:"
    echo "   • macOS: brew install ffmpeg"
    echo "   • Ubuntu: sudo apt install ffmpeg"
    echo "   • Windows: Descarga desde https://ffmpeg.org/"
fi

# Verificar ffprobe
if command -v ffprobe &> /dev/null; then
    echo "✅ ffprobe está instalado"
else
    echo "❌ ffprobe no está instalado (viene con ffmpeg)"
fi

echo ""
echo "🚀 INICIAR LA APLICACIÓN"
echo "========================"
echo ""

echo "Una vez configuradas las API keys, puedes iniciar la aplicación con:"
echo ""
echo "1. Desde la raíz del proyecto:"
echo "   ./start.sh"
echo ""
echo "2. O manualmente:"
echo "   cd backend && bundle exec rails server -p 3001"
echo "   cd frontend && npm start"
echo ""

echo "📚 DOCUMENTACIÓN ADICIONAL"
echo "=========================="
echo ""
echo "• Ver TRANSCRIPTION_SETUP.md para más detalles"
echo "• Ver README.md para información general"
echo "• Ver MEJORAS_IMPLEMENTADAS.md para cambios recientes"
echo ""

echo "🎯 PRÓXIMOS PASOS"
echo "================="
echo ""
echo "1. Configura al menos una API key en el archivo .env"
echo "2. Inicia la aplicación con ./start.sh"
echo "3. Sube un archivo de video/audio/texto"
echo "4. El sistema procesará automáticamente el contenido"
echo ""

echo "✅ Configuración completada!"
echo ""
echo "¿Necesitas ayuda? Revisa la documentación o contacta al equipo de desarrollo."


