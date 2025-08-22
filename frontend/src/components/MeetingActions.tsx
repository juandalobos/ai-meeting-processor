import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { meetingsApi } from '../services/api';
import { Meeting } from '../types';

interface MeetingActionsProps {
  meeting: Meeting;
  onProcessingStarted: () => void;
}

const MeetingActions: React.FC<MeetingActionsProps> = ({ meeting, onProcessingStarted }) => {
  const { t, i18n } = useTranslation();
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState('');

  const handleProcessContent = async (jobType: 'proposal' | 'jira_ticket' | 'executive_summary') => {
    setLoading(jobType);
    setError('');

    try {
      await meetingsApi.processContent(meeting.id, jobType, i18n.language);
      onProcessingStarted();
    } catch (err: any) {
      // Extraer mensaje de error más específico
      let errorMessage = t('meetingActions.error', { type: jobType });
      
      if (err.response?.data?.error) {
        errorMessage = err.response.data.error;
      } else if (err.message) {
        errorMessage = err.message;
      }
      
      // Agregar sugerencias específicas según el tipo de error
      if (errorMessage.includes('sobrecargada') || errorMessage.includes('overloaded')) {
        errorMessage += '\n\n💡 Sugerencias:\n• Espera 5-10 minutos y vuelve a intentar\n• Intenta con archivos más pequeños\n• Verifica tu conexión a internet';
      } else if (errorMessage.includes('video') || errorMessage.includes('audio')) {
        errorMessage += '\n\n💡 Para archivos de video/audio:\n• Proporciona una transcripción en formato .txt\n• Convierte el video a texto usando herramientas externas\n• Escribe manualmente los puntos principales\n\n🎯 Herramientas recomendadas:\n• Otter.ai (transcripción automática gratuita)\n• Google Docs (herramienta de transcripción)\n• Microsoft Word (transcripción de audio)';
      } else if (errorMessage.includes('timeout')) {
        errorMessage += '\n\n💡 Para problemas de timeout:\n• Intenta con contenido más corto\n• Verifica tu conexión a internet\n• Espera 15-30 minutos y vuelve a intentar\n• Usa archivos de texto en lugar de video';
      }
      
      setError(errorMessage);
      console.error(`Error processing ${jobType}:`, err);
    } finally {
      setLoading(null);
    }
  };

  return (
    <div className="meeting-actions">
      <h3>{t('meetingActions.title')}</h3>
      <p>{t('meetingActions.description')}</p>
      
      <div className="action-buttons">
        <button
          onClick={() => handleProcessContent('proposal')}
          disabled={loading === 'proposal'}
          className="action-button proposal"
        >
          {loading === 'proposal' ? t('meetingActions.generating') : t('meetingActions.generateProposal')}
        </button>
        
        <button
          onClick={() => handleProcessContent('jira_ticket')}
          disabled={loading === 'jira_ticket'}
          className="action-button jira"
        >
          {loading === 'jira_ticket' ? t('meetingActions.generating') : t('meetingActions.generateJiraTickets')}
        </button>
        
        <button
          onClick={() => handleProcessContent('executive_summary')}
          disabled={loading === 'executive_summary'}
          className="action-button executive"
        >
          {loading === 'executive_summary' ? t('meetingActions.generating') : t('meetingActions.generateExecutiveSummary')}
        </button>
      </div>

      {error && (
        <div className="error">
          <strong>❌ Error</strong>
          {error}
          <div style={{ marginTop: '1rem', display: 'flex', gap: '0.5rem' }}>
            <button 
              onClick={() => setError('')}
              style={{
                padding: '0.5rem 1rem',
                backgroundColor: 'rgba(255, 255, 255, 0.2)',
                border: '1px solid rgba(255, 255, 255, 0.3)',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '0.8rem'
              }}
            >
              Cerrar
            </button>
            <button 
              onClick={() => {
                setError('');
                // El usuario puede intentar nuevamente haciendo clic en el botón correspondiente
              }}
              style={{
                padding: '0.5rem 1rem',
                backgroundColor: 'rgba(255, 255, 255, 0.3)',
                border: '1px solid rgba(255, 255, 255, 0.4)',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '0.8rem'
              }}
            >
              Intentar Nuevamente
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default MeetingActions;
