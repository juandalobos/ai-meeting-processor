# Configuración de Transcripción Automática de Videos

## 🎯 Funcionalidad Implementada

El sistema ahora puede procesar automáticamente videos y audio para generar transcripciones usando IA, sin necesidad de transcripción manual.

## 🔧 Servicios de Transcripción Soportados

### 1. **OpenAI Whisper API** (Recomendado)
- **Ventajas**: Alta precisión, soporte multiidioma, fácil configuración
- **Costo**: ~$0.006 por minuto de audio
- **Configuración**: Solo necesitas una API key de OpenAI

### 2. **Google Speech-to-Text** (Alternativa)
- **Ventajas**: Muy preciso, bueno para español
- **Costo**: ~$0.006 por minuto
- **Configuración**: Requiere credenciales de Google Cloud

### 3. **Azure Speech Services** (Alternativa)
- **Ventajas**: Integración con Microsoft, bueno para empresas
- **Costo**: ~$0.006 por minuto
- **Configuración**: Requiere clave de Azure

### 4. **Fallback con Gemini** (Sin costo adicional)
- **Ventajas**: Usa la API de Gemini que ya tienes
- **Limitaciones**: No es transcripción real, sino generación basada en metadatos
- **Configuración**: No requiere configuración adicional

## 🚀 Configuración Rápida (Whisper API)

### Paso 1: Obtener API Key de OpenAI
1. Ve a [OpenAI Platform](https://platform.openai.com/)
2. Crea una cuenta o inicia sesión
3. Ve a "API Keys" y crea una nueva clave
4. Copia la clave

### Paso 2: Configurar Variables de Entorno
1. Crea un archivo `.env` en la carpeta `backend/`
2. Agrega tu API key:

```bash
# API Keys for AI Services
GEMINI_API_KEY=tu_gemini_api_key_aqui
OPENAI_API_KEY=tu_openai_api_key_aqui
```

### Paso 3: Reiniciar el Servidor
```bash
cd backend
bundle exec rails server -p 3001
```

## 📋 Flujo de Procesamiento

1. **Subir Video**: El usuario sube un archivo de video
2. **Detección de Audio**: El sistema detecta si el video tiene audio
3. **Transcripción Automática**: 
   - Si tiene Whisper API: Usa Whisper para transcripción real
   - Si no tiene: Usa Gemini para generar contenido basado en metadatos
4. **Análisis de Contenido**: La IA analiza la transcripción
5. **Generación de Resultados**: Crea propuestas, tickets Jira, y resúmenes

## 💡 Ventajas del Sistema

### ✅ **Procesamiento Automático**
- No requiere transcripción manual
- Procesa videos de cualquier duración
- Soporte para múltiples idiomas

### ✅ **Fallback Inteligente**
- Si falla la transcripción, usa metadatos del video
- Proporciona resultados útiles incluso sin transcripción perfecta
- Mensajes informativos para el usuario

### ✅ **Interfaz Mejorada**
- Indicadores de progreso claros
- Opciones de transcripción manual como respaldo
- Enlaces directos a herramientas externas

## 🔍 Ejemplo de Uso

1. **Subir Video**: `Sync - Appoiments con datos duplicados.mp4`
2. **Procesamiento Automático**: 
   - Extrae audio del video
   - Transcribe con Whisper API
   - Analiza contenido sobre "datos duplicados"
3. **Resultados Generados**:
   - Propuesta de solución
   - Tickets Jira para implementar mejoras
   - Resumen ejecutivo de la reunión

## 🛠️ Solución de Problemas

### Error: "OpenAI API key not found"
- Verifica que `OPENAI_API_KEY` esté en tu archivo `.env`
- Reinicia el servidor después de agregar la variable

### Error: "Transcription failed"
- Verifica que el video tenga audio
- Asegúrate de que la API key tenga créditos disponibles
- Revisa los logs del servidor para más detalles

### Video sin audio
- El sistema detectará automáticamente videos sin audio
- Proporcionará opciones alternativas al usuario

## 📊 Costos Estimados

- **Whisper API**: ~$0.006 por minuto de audio
- **Video de 26 minutos**: ~$0.16 por transcripción
- **100 videos por mes**: ~$16 USD

## 🎯 Próximos Pasos

1. **Configurar Whisper API** para transcripción real
2. **Probar con tu video** actual
3. **Ajustar prompts** según tus necesidades específicas
4. **Considerar Google Speech-to-Text** si necesitas mayor precisión en español

¡El sistema ahora procesa videos automáticamente! 🎉
