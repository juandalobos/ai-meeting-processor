# Procesamiento de Archivos Grandes

## 🚀 Nuevas Capacidades

El sistema ahora puede procesar archivos grandes de manera eficiente:

### 📹 Videos Largos
- **Tamaño máximo**: 100MB
- **Formatos soportados**: MP4, AVI, MOV, WMV, FLV, WebM, MKV
- **Procesamiento**: Dividido en chunks de 10 minutos
- **Transcripción**: Audio extraído y transcrito por chunks

### 📄 Documentos Extensos
- **Tamaño máximo**: 100MB
- **Formatos soportados**: PDF, DOCX, DOC, TXT
- **Procesamiento**: Texto extraído y dividido en chunks de 100k caracteres

### 📝 Textos Largos
- **Límite**: 100,000 caracteres por chunk
- **Procesamiento**: División inteligente por párrafos y oraciones
- **Análisis**: Cada chunk procesado individualmente y luego combinado

## 🔧 Instalación

### 1. Instalar FFmpeg (para videos)
```bash
cd backend
./setup_ffmpeg.sh
```

### 2. Verificar dependencias
```bash
bundle install
```

## 📊 Procesamiento Automático

### Detección de Archivos Grandes
- **Archivos > 10MB**: Procesamiento automático en chunks
- **Archivos < 10MB**: Procesamiento normal
- **Videos largos**: División automática en segmentos de 10 minutos

### Estados del Procesamiento
- `pending`: Archivo subido, esperando procesamiento
- `processing`: Procesamiento en curso
- `completed`: Procesamiento completado exitosamente
- `failed`: Error en el procesamiento

## 🎯 API Endpoints

### Procesar Contenido
```http
POST /api/meetings/:id/process_content
Content-Type: application/json

{
  "job_type": "executive_summary|jira_ticket|proposal",
  "language": "es|en",
  "sync": "true" // Para procesamiento síncrono
}
```

### Verificar Estado
```http
GET /api/meetings/:id/processing_status
```

### Respuesta de Estado
```json
{
  "meeting_id": 1,
  "status": "processing",
  "file_size": 52428800,
  "is_large_file": true,
  "processing_jobs": [
    {
      "job_type": "executive_summary",
      "status": "completed",
      "created_at": "2025-08-31T20:53:10.022Z",
      "updated_at": "2025-08-31T20:53:10.022Z",
      "has_result": true
    }
  ]
}
```

## ⚡ Optimizaciones

### Para Videos
1. **División en chunks**: Videos largos se dividen en segmentos de 10 minutos
2. **Transcripción paralela**: Cada chunk se transcribe independientemente
3. **Combinación inteligente**: Transcripciones se combinan manteniendo contexto

### Para Textos
1. **División por párrafos**: Respeta la estructura del documento
2. **División por oraciones**: Para párrafos muy largos
3. **División por palabras**: Para oraciones extremadamente largas

### Para Documentos
1. **Extracción de texto**: PDF y DOCX se convierten a texto plano
2. **Preservación de estructura**: Mantiene párrafos y formato
3. **Procesamiento en chunks**: Texto largo se divide para análisis

## 🔍 Monitoreo

### Logs del Sistema
```bash
tail -f backend/log/development.log
```

### Verificar Jobs
```bash
# Ver jobs en cola
rails console
> Sidekiq::Queue.new.size

# Ver jobs procesados
> ProcessingJob.count
```

## 🛠️ Solución de Problemas

### Error: "Archivo demasiado grande"
- **Causa**: Archivo excede 100MB
- **Solución**: Comprimir o dividir el archivo

### Error: "FFmpeg no encontrado"
- **Causa**: FFmpeg no está instalado
- **Solución**: Ejecutar `./setup_ffmpeg.sh`

### Error: "Transcripción fallida"
- **Causa**: Audio no claro o formato no soportado
- **Solución**: Verificar calidad del audio y formato

### Procesamiento lento
- **Causa**: Archivo muy grande
- **Solución**: El sistema procesa automáticamente en chunks

## 📈 Rendimiento

### Tiempos Estimados
- **Archivos pequeños (< 10MB)**: 30 segundos - 2 minutos
- **Archivos medianos (10-50MB)**: 2-5 minutos
- **Archivos grandes (50-100MB)**: 5-15 minutos

### Factores que Afectan el Rendimiento
- **Tamaño del archivo**: Más grande = más tiempo
- **Calidad del audio**: Audio claro = transcripción más rápida
- **Complejidad del contenido**: Contenido técnico = análisis más largo
- **Conexión a internet**: APIs externas requieren conexión estable

## 🔐 Seguridad

### Límites de Archivo
- **Tamaño máximo**: 100MB por archivo
- **Tipos permitidos**: Video, audio, documentos, texto
- **Escaneo**: Archivos se escanean antes del procesamiento

### Almacenamiento Temporal
- **Chunks**: Se almacenan temporalmente en `/tmp`
- **Limpieza**: Archivos temporales se eliminan automáticamente
- **Privacidad**: No se almacenan permanentemente

## 🎉 Casos de Uso

### Reuniones Largas
- **Videos de 1-2 horas**: Procesados en chunks de 10 minutos
- **Transcripción completa**: Audio de toda la reunión
- **Resumen ejecutivo**: Análisis de todo el contenido

### Documentos Técnicos
- **Manuales largos**: PDFs de cientos de páginas
- **Especificaciones**: Documentos técnicos extensos
- **Reportes**: Análisis de documentos complejos

### Grabaciones de Audio
- **Podcasts**: Episodios largos
- **Entrevistas**: Conversaciones extensas
- **Presentaciones**: Audio de presentaciones largas
