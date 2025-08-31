# Configuración de Transcripción de Audio/Video

Este sistema ahora incluye capacidades completas de transcripción automática de audio y video usando múltiples servicios.

## 🚀 Servicios de Transcripción Disponibles

### 1. OpenAI Whisper API (Recomendado)
- **Ventajas**: Alta precisión, soporte multiidioma, fácil configuración
- **Costo**: ~$0.006 por minuto
- **Configuración**: Solo necesitas una API key de OpenAI

### 2. AWS Transcribe
- **Ventajas**: Integración con AWS, procesamiento asíncrono
- **Costo**: ~$0.024 por minuto
- **Configuración**: Requiere credenciales AWS y bucket S3

### 3. Google Speech-to-Text
- **Ventajas**: Alta precisión, múltiples idiomas
- **Costo**: ~$0.006 por minuto
- **Configuración**: Requiere credenciales de Google Cloud

## 🔧 Configuración Rápida

### Opción 1: OpenAI Whisper (Más Fácil)

1. Ve a https://platform.openai.com
2. Crea una cuenta y obtén una API key
3. Agrega al archivo `.env`:
```bash
OPENAI_API_KEY=sk-tu-api-key-aqui
```

### Opción 2: AWS Transcribe

1. Crea una cuenta en AWS
2. Crea un bucket S3 para transcripciones
3. Crea un usuario IAM con permisos para Transcribe y S3
4. Agrega al archivo `.env`:
```bash
AWS_ACCESS_KEY_ID=tu-access-key
AWS_SECRET_ACCESS_KEY=tu-secret-key
AWS_REGION=us-east-1
AWS_S3_BUCKET=tu-bucket-name
```

### Opción 3: Google Speech-to-Text

1. Crea un proyecto en Google Cloud
2. Habilita Speech-to-Text API
3. Crea una cuenta de servicio y descarga las credenciales JSON
4. Agrega al archivo `.env`:
```bash
GOOGLE_CLOUD_CREDENTIALS={"type":"service_account",...}
```

## 📁 Archivos Soportados

### Video
- MP4, AVI, MOV, MKV
- Cualquier formato que contenga audio

### Audio
- MP3, WAV, M4A, FLAC
- Formatos comprimidos y sin comprimir

### Texto
- TXT, PDF
- Transcripciones manuales

## 🔄 Flujo de Procesamiento

1. **Subida de archivo**: El sistema detecta automáticamente el tipo de archivo
2. **Transcripción**: Se usa el mejor servicio disponible
3. **Análisis**: Gemini procesa la transcripción para generar:
   - Resumen ejecutivo
   - Propuestas técnicas
   - Tickets de Jira
4. **Resultados**: Se muestran en la interfaz web

## 🛠️ Instalación de Dependencias

```bash
# Instalar ffmpeg (para procesamiento local)
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt update
sudo apt install ffmpeg

# Windows
# Descarga desde https://ffmpeg.org/download.html
```

## 🧪 Pruebas

Para probar la transcripción:

1. Configura al menos una API key
2. Sube un archivo de video/audio
3. El sistema transcribirá automáticamente
4. Generará análisis completos

## 📊 Monitoreo

Los logs muestran:
- Método de transcripción usado
- Duración del proceso
- Longitud de la transcripción
- Errores si ocurren

## 🔒 Seguridad

- Los archivos se procesan temporalmente
- Se eliminan automáticamente después del procesamiento
- Las API keys se almacenan de forma segura
- No se almacenan transcripciones permanentemente

## 🆘 Solución de Problemas

### Error: "No transcription APIs available"
- Configura al menos una API key
- Verifica que las credenciales sean correctas

### Error: "Transcription failed"
- Verifica que el archivo contenga audio
- Asegúrate de que el formato sea compatible
- Revisa los logs para más detalles

### Error: "File too large"
- Los archivos grandes pueden tardar más
- Considera dividir archivos muy largos

## 💡 Consejos

1. **OpenAI Whisper** es la opción más fácil y económica
2. Para archivos grandes, usa **AWS Transcribe** (procesamiento asíncrono)
3. Para múltiples idiomas, **Google Speech-to-Text** es excelente
4. Siempre verifica que el archivo contenga audio válido
5. Los formatos MP4 y MP3 funcionan mejor

## 📞 Soporte

Si tienes problemas:
1. Revisa los logs en `log/development.log`
2. Verifica la configuración de las API keys
3. Asegúrate de que ffmpeg esté instalado
4. Prueba con archivos más pequeños primero
