#!/bin/bash

echo "🎯 Configuración de Transcripción de Audio/Video"
echo "================================================"
echo ""

# Verificar si ffmpeg está instalado
if command -v ffmpeg &> /dev/null; then
    echo "✅ ffmpeg está instalado"
else
    echo "❌ ffmpeg no está instalado"
    echo "Instalando ffmpeg..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install ffmpeg
        else
            echo "❌ Homebrew no está instalado. Instala ffmpeg manualmente desde https://ffmpeg.org/download.html"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        sudo apt update && sudo apt install -y ffmpeg
    else
        echo "❌ Sistema operativo no soportado. Instala ffmpeg manualmente desde https://ffmpeg.org/download.html"
    fi
fi

echo ""
echo "🔧 Configuración de APIs de Transcripción"
echo "========================================="
echo ""

# Crear archivo .env si no existe
if [ ! -f .env ]; then
    echo "📝 Creando archivo .env..."
    cat > .env << 'ENVEOF'
# Google Gemini API Key
GEMINI_API_KEY=AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0

# OpenAI API Key for Whisper transcription (RECOMMENDED)
# Obtén tu API key en: https://platform.openai.com/api-keys
OPENAI_API_KEY=your_openai_api_key_here

# AWS Credentials for AWS Transcribe (Optional)
# AWS_ACCESS_KEY_ID=your_aws_access_key_id
# AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
# AWS_REGION=us-east-1
# AWS_S3_BUCKET=your-transcription-bucket

# Google Cloud Speech-to-Text (Optional)
# GOOGLE_CLOUD_CREDENTIALS={"type":"service_account",...}

# Database Configuration
DATABASE_URL=postgresql://postgres:password@localhost:5432/ai_meeting_processor

# Redis Configuration (for Sidekiq)
REDIS_URL=redis://localhost:6379/0

# Rails Environment
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key_base_here
ENVEOF
    echo "✅ Archivo .env creado"
else
    echo "✅ Archivo .env ya existe"
fi

echo ""
echo "🚀 Configuración Rápida de OpenAI Whisper"
echo "========================================="
echo ""

echo "Para habilitar transcripción automática:"
echo ""
echo "1. Ve a https://platform.openai.com/api-keys"
echo "2. Crea una cuenta o inicia sesión"
echo "3. Crea una nueva API key"
echo "4. Copia la API key"
echo "5. Edita el archivo .env y reemplaza 'your_openai_api_key_here' con tu API key"
echo "6. Reinicia el servidor"
echo ""

echo "💡 Alternativas:"
echo "- AWS Transcribe: Configura credenciales AWS"
echo "- Google Speech-to-Text: Configura Google Cloud"
echo ""

echo "📖 Para más información, consulta TRANSCRIPTION_SETUP.md"
echo ""

echo "🎉 ¡Configuración completada!"
echo ""
echo "Próximos pasos:"
echo "1. Configura tu API key de OpenAI"
echo "2. Reinicia el servidor: bundle exec rails server -p 3001"
echo "3. Sube un archivo de video/audio"
echo "4. ¡Disfruta de la transcripción automática!"
