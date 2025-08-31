# Solución para Procesamiento de Videos

## 🎯 PROBLEMA RESUELTO

Implementación completa de procesamiento de videos que combina:
- **FFmpeg** para extracción de audio
- **OpenAI Whisper** para transcripción
- **Gemini API** para procesamiento de contenido

## 🔧 ARQUITECTURA DE LA SOLUCIÓN

### Flujo de Procesamiento
```
Video → FFmpeg → Audio → Whisper → Texto → Gemini → Resultado
```

### Componentes Implementados

#### 1. **VideoProcessorService** (`app/services/video_processor_service.rb`)
- **Responsabilidad**: Coordinar todo el proceso de video
- **Funciones**:
  - Detectar si FFmpeg está disponible
  - Extraer audio del video con FFmpeg
  - Transcribir audio con Whisper
  - Procesar texto con Gemini
  - Manejo de errores y fallbacks

#### 2. **GeminiService Actualizado** (`app/services/gemini_service.rb`)
- **Nuevo método**: `process_meeting_content_from_text()`
- **Función**: Procesar texto directamente sin necesidad de archivo
- **Compatibilidad**: Mantiene todos los métodos existentes

#### 3. **Controlador Actualizado** (`app/controllers/api/meetings_controller.rb`)
- **Nuevo método**: `video_file?()` para detectar videos
- **Lógica**: Usa VideoProcessorService para videos, GeminiService para otros archivos
- **Soporte**: Múltiples formatos de video

#### 4. **Jobs Actualizados** (`app/jobs/process_meeting_job.rb`)
- **Detección automática**: Videos vs otros archivos
- **Procesamiento específico**: VideoProcessorService para videos
- **Compatibilidad**: Mantiene procesamiento existente para otros archivos

## 📋 FORMATOS SOPORTADOS

### Videos
- **MP4** (recomendado)
- **AVI**
- **MOV**
- **WMV**
- **FLV**
- **WebM**
- **MKV**
- **M4V**

### Audio (extraído automáticamente)
- **WAV** (16kHz, mono, PCM)
- **Optimizado para Whisper**

## 🛠️ CONFIGURACIÓN REQUERIDA

### 1. **FFmpeg**
```bash
# Instalación automática
./setup_ffmpeg.sh

# O manualmente:
# macOS: brew install ffmpeg
# Ubuntu: sudo apt-get install ffmpeg
# Windows: Descargar desde https://ffmpeg.org/
```

### 2. **Variables de Entorno**
```bash
# .env
OPENAI_API_KEY=tu_clave_de_openai
GEMINI_API_KEY=tu_clave_de_gemini
```

### 3. **Dependencias Ruby**
```ruby
# Gemfile
gem 'openai'  # Para Whisper API
gem 'httparty' # Para HTTP requests
```

## 🚀 CÓMO USAR

### Desde el Frontend
1. Ve a `http://localhost:3000`
2. Sube un archivo de video
3. Haz clic en "GENERAR PROPUESTA" o "GENERAR RESUMEN EJECUTIVO"
4. El sistema procesará automáticamente el video

### Desde la API
```bash
# Procesar video
curl -X POST "http://localhost:3001/api/meetings/ID/process_content" \
  -H "Content-Type: application/json" \
  -d '{"job_type": "proposal", "language": "es", "sync": "true"}'
```

## 🔍 PROCESO DETALLADO

### Paso 1: Extracción de Audio
```bash
ffmpeg -i video.mp4 -vn -acodec pcm_s16le -ar 16000 -ac 1 audio.wav -y
```
- **Parámetros optimizados para Whisper**:
  - `-vn`: Sin video
  - `-acodec pcm_s16le`: Audio PCM 16-bit
  - `-ar 16000`: Sample rate 16kHz
  - `-ac 1`: Mono

### Paso 2: Transcripción con Whisper
```ruby
response = client.audio.transcribe(
  parameters: {
    model: "whisper-1",
    file: audio_file,
    language: "auto",
    response_format: "text",
    temperature: 0.0,
    prompt: "Esta es una reunión de trabajo..."
  }
)
```

### Paso 3: Procesamiento con Gemini
```ruby
result = gemini_service.process_meeting_content_from_text(
  transcription, 
  job_type, 
  language
)
```

## 🧪 PRUEBAS

### Script de Verificación
```bash
ruby test_video_processing.rb
```

### Verificaciones Automáticas
- ✅ Servidor funcionando
- ✅ FFmpeg instalado
- ✅ Variables de entorno configuradas
- ✅ Servicios cargados correctamente
- ✅ Métodos disponibles

## 📊 RENDIMIENTO

### Tiempos Estimados
- **Extracción de audio**: 1-5 segundos (depende del tamaño)
- **Transcripción Whisper**: 10-60 segundos (depende de la duración)
- **Procesamiento Gemini**: 5-15 segundos
- **Total**: 15-80 segundos

### Optimizaciones
- **Audio optimizado**: 16kHz mono para Whisper
- **Procesamiento paralelo**: Audio y video separados
- **Manejo de errores**: Fallbacks automáticos
- **Limpieza**: Archivos temporales automáticos

## 🛡️ MANEJO DE ERRORES

### Errores Comunes y Soluciones

#### 1. **FFmpeg no instalado**
```
Error: FFmpeg no está instalado
Solución: Ejecutar ./setup_ffmpeg.sh
```

#### 2. **Video sin audio**
```
Error: No se pudo extraer audio del video
Solución: Verificar que el video tenga pista de audio
```

#### 3. **API de Whisper falla**
```
Error: Whisper transcription failed
Solución: Verificar OPENAI_API_KEY
```

#### 4. **Video corrupto**
```
Error: Invalid video file
Solución: Verificar integridad del archivo
```

### Fallbacks Automáticos
- **Sin FFmpeg**: Mensaje de error con instrucciones
- **Sin Whisper**: Mensaje de error con alternativas
- **Sin Gemini**: Procesamiento básico local

## 🔧 MANTENIMIENTO

### Logs
```bash
# Ver logs de procesamiento
tail -f log/development.log | grep "VIDEO PROCESSING"
```

### Monitoreo
- **Tiempo de procesamiento**
- **Tasa de éxito**
- **Errores comunes**
- **Uso de recursos**

### Actualizaciones
- **FFmpeg**: `brew upgrade ffmpeg` (macOS)
- **Whisper**: Automático via API
- **Gemini**: Automático via API

## 🎉 BENEFICIOS

### Para el Usuario
- **Procesamiento automático**: Sin intervención manual
- **Múltiples formatos**: Soporte amplio de videos
- **Resultados rápidos**: 15-80 segundos total
- **Alta calidad**: Whisper + Gemini

### Para el Sistema
- **Escalabilidad**: Procesamiento en background
- **Confiabilidad**: Múltiples fallbacks
- **Mantenibilidad**: Código modular
- **Extensibilidad**: Fácil agregar nuevos formatos

## 📈 PRÓXIMOS PASOS

### Mejoras Futuras
1. **Procesamiento de chunks**: Para videos muy largos
2. **Detección de idioma**: Automática antes de Whisper
3. **Compresión de audio**: Para archivos grandes
4. **Cache de transcripciones**: Evitar reprocesar
5. **Procesamiento paralelo**: Múltiples videos simultáneos

### Integraciones Adicionales
- **Google Speech-to-Text**: Alternativa a Whisper
- **Azure Speech Services**: Más opciones
- **AWS Transcribe**: Para usuarios AWS
- **Local Whisper**: Sin dependencia de API

---

**Estado**: ✅ **IMPLEMENTADO Y FUNCIONAL**
