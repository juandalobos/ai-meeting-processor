# 🚀 Configuración Rápida - Transcripción Automática

## ✅ Estado Actual
- ✅ **Backend**: Funcionando en http://localhost:3001
- ✅ **Frontend**: Funcionando en http://localhost:3000
- ✅ **Sistema de transcripción**: Implementado y listo

## 🔧 Configuración Inmediata (5 minutos)

### Paso 1: Obtener API Key de OpenAI
1. Ve a https://platform.openai.com/api-keys
2. Crea una cuenta o inicia sesión
3. Crea una nueva API key
4. Copia la clave (empieza con `sk-`)

### Paso 2: Configurar la API Key
```bash
# En el archivo backend/.env, cambia esta línea:
OPENAI_API_KEY=your_openai_api_key_here

# Por tu API key real:
OPENAI_API_KEY=sk-tu-api-key-aqui
```

### Paso 3: Reiniciar el Servidor
```bash
cd backend
pkill -f "puma.*3001"
bundle exec rails server -p 3001
```

## 🎯 ¡Listo para Usar!

### Funcionalidades Disponibles:
1. **Transcripción Automática**: Sube videos/audio y se transcriben automáticamente
2. **Resumen Ejecutivo**: Genera resúmenes completos de reuniones
3. **Propuestas Técnicas**: Crea propuestas basadas en el contenido
4. **Tickets Jira**: Genera tickets estructurados para desarrollo

### Formatos Soportados:
- **Video**: MP4, AVI, MOV, MKV
- **Audio**: MP3, WAV, M4A, FLAC
- **Texto**: TXT, PDF

### Costo Estimado:
- **OpenAI Whisper**: ~$0.006 por minuto
- **Video de 30 minutos**: ~$0.18
- **100 videos por mes**: ~$18 USD

## 🆘 Si Tienes Problemas

### Error: "No transcription APIs available"
- Verifica que la API key esté configurada correctamente
- Reinicia el servidor después de cambiar la configuración

### Error: "Network Error"
- Asegúrate de que ambos servicios estén ejecutándose:
  - Backend: http://localhost:3001
  - Frontend: http://localhost:3000

### Error: "Transcription failed"
- Verifica que el archivo contenga audio
- Asegúrate de que el formato sea compatible
- Revisa que la API key tenga créditos disponibles

## 📞 Soporte Rápido

**Comandos útiles:**
```bash
# Verificar estado de servicios
curl http://localhost:3001/api/health
curl http://localhost:3000

# Reiniciar backend
cd backend && pkill -f puma && bundle exec rails server -p 3001

# Reiniciar frontend
cd frontend && npm start
```

**Logs importantes:**
- Backend: `backend/log/development.log`
- Frontend: Consola del navegador (F12)

## 🎉 ¡Disfruta de la Transcripción Automática!

Una vez configurado, podrás:
1. Subir cualquier video/audio
2. Obtener transcripción automática
3. Generar análisis completos
4. Crear propuestas y tickets automáticamente

¡El sistema está listo para procesar tus reuniones! 🚀
