#!/bin/bash

echo "=== INSTALACIÓN DE FFMPEG PARA PROCESAMIENTO DE VIDEOS ==="
echo

# Detectar el sistema operativo
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detectado: macOS"
    echo "Instalando FFmpeg con Homebrew..."
    
    # Verificar si Homebrew está instalado
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew no está instalado. Instalando Homebrew primero..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Instalar FFmpeg
    brew install ffmpeg
    
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Detectado: Linux"
    
    # Detectar la distribución
    if command -v apt-get &> /dev/null; then
        echo "Distribución basada en Debian/Ubuntu"
        sudo apt-get update
        sudo apt-get install -y ffmpeg
        
    elif command -v yum &> /dev/null; then
        echo "Distribución basada en Red Hat/CentOS"
        sudo yum install -y ffmpeg
        
    elif command -v dnf &> /dev/null; then
        echo "Distribución basada en Fedora"
        sudo dnf install -y ffmpeg
        
    elif command -v pacman &> /dev/null; then
        echo "Distribución basada en Arch Linux"
        sudo pacman -S ffmpeg
        
    else
        echo "❌ No se pudo detectar el gestor de paquetes"
        echo "Por favor, instala FFmpeg manualmente desde: https://ffmpeg.org/download.html"
        exit 1
    fi
    
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    echo "Detectado: Windows (Git Bash/Cygwin)"
    echo "❌ Para Windows, por favor instala FFmpeg manualmente:"
    echo "1. Ve a https://ffmpeg.org/download.html"
    echo "2. Descarga la versión para Windows"
    echo "3. Extrae y agrega FFmpeg al PATH del sistema"
    exit 1
    
else
    echo "❌ Sistema operativo no reconocido: $OSTYPE"
    echo "Por favor, instala FFmpeg manualmente desde: https://ffmpeg.org/download.html"
    exit 1
fi

echo
echo "Verificando instalación..."

if command -v ffmpeg &> /dev/null; then
    echo "✅ FFmpeg instalado correctamente"
    echo "Versión: $(ffmpeg -version | head -n1)"
    echo
    echo "🎉 ¡FFmpeg está listo para procesar videos!"
    echo
    echo "Ahora puedes:"
    echo "1. Subir videos a la aplicación"
    echo "2. El sistema extraerá automáticamente el audio"
    echo "3. Transcribirá el audio con Whisper"
    echo "4. Procesará el contenido con Gemini"
    echo
    echo "Formatos de video soportados:"
    echo "- MP4, AVI, MOV, WMV, FLV, WebM, MKV, M4V"
else
    echo "❌ Error: FFmpeg no se instaló correctamente"
    echo "Por favor, intenta instalar manualmente desde: https://ffmpeg.org/download.html"
    exit 1
fi
