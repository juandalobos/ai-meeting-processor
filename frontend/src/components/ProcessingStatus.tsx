import React, { useEffect, useState, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { processingJobsApi, meetingsApi } from '../services/api';
import { ProcessingJob } from '../types';

interface ProcessingStatusProps {
  meetingId: number;
  onStatusChange: () => void;
  onNewProcessingStarted: () => void;
}

const ProcessingStatus: React.FC<ProcessingStatusProps> = ({ 
  meetingId, 
  onStatusChange, 
  onNewProcessingStarted 
}) => {
  const { t, i18n } = useTranslation();
  const [jobs, setJobs] = useState<ProcessingJob[]>([]);
  const [loading, setLoading] = useState(true);
  const [processingAction, setProcessingAction] = useState<string | null>(null);
  const [translatingJobs, setTranslatingJobs] = useState<Set<string>>(new Set());

  const fetchJobs = useCallback(async () => {
    try {
      const jobsData = await processingJobsApi.getByMeeting(meetingId);
      setJobs(jobsData);
    } catch (err) {
      console.error('Error fetching jobs:', err);
    } finally {
      setLoading(false);
    }
  }, [meetingId]);

  useEffect(() => {
    fetchJobs();
    
    // Poll for updates every 5 seconds
    const interval = setInterval(fetchJobs, 5000);
    
    return () => clearInterval(interval);
  }, [meetingId, fetchJobs]);

  const handleProcessContent = async (jobType: 'proposal' | 'jira_ticket' | 'executive_summary') => {
    setProcessingAction(jobType);
    setLoading(true);

    try {
      await meetingsApi.processContent(meetingId, jobType, i18n.language);
      onNewProcessingStarted();
      // Refresh jobs immediately after starting new processing
      setTimeout(fetchJobs, 1000);
    } catch (err) {
      console.error(`Error processing ${jobType}:`, err);
    } finally {
      setProcessingAction(null);
      setLoading(false);
    }
  };

  const handleTranslateResult = async (jobType: 'proposal' | 'jira_ticket' | 'executive_summary') => {
    try {
      // Add to translating set
      setTranslatingJobs(prev => new Set(prev).add(jobType));
      
      // Show loading state
      const job = jobs.find(j => j.job_type === jobType);
      if (job) {
        setJobs(prevJobs => 
          prevJobs.map(j => 
            j.id === job.id 
              ? { ...j, result: j.result + '\n\n🔄 Traduciendo...' }
              : j
          )
        );
      }
      
      await meetingsApi.translateResult(meetingId, jobType, i18n.language);
      // Refresh jobs after translation
      setTimeout(fetchJobs, 1000);
    } catch (err) {
      console.error(`Error translating ${jobType}:`, err);
      // Revert status on error
      setTimeout(fetchJobs, 1000);
    } finally {
      // Remove from translating set
      setTranslatingJobs(prev => {
        const newSet = new Set(prev);
        newSet.delete(jobType);
        return newSet;
      });
    }
  };

  // Function to detect if content is in English
  const isContentInEnglish = (content: string): boolean => {
    if (!content) return false;
    
    // Common English words and patterns
    const englishPatterns = [
      /\b(the|and|for|are|but|not|you|all|can|had|her|was|one|our|out|day|get|has|him|his|how|man|new|now|old|see|two|way|who|boy|did|its|let|put|say|she|too|use)\b/gi,
      /\b(meeting|summary|executive|proposal|ticket|task|priority|high|medium|low|problem|solution|action|items|responsibilities|assignments|decisions|risks|considerations)\b/gi,
      /\b(analysis|implementation|development|testing|deployment|management|strategy|planning|execution|monitoring|evaluation|assessment)\b/gi
    ];
    
    const spanishPatterns = [
      /\b(el|la|los|las|de|que|y|a|en|un|es|se|no|te|lo|le|da|su|por|son|con|para|al|del|una|más|o|pero|sus|me|hasta|hay|donde|han|quien|están|estado|desde|todo|nos|durante|todos|uno|les|ni|contra|otros|ese|eso|ante|ellos|e|esto|mí|antes|algunos|qué|unos|yo|otro|otras|otra|él|tanto|esa|estos|mucho|quienes|nada|muchos|cual|poco|ella|estar|estas|algunas|algo|nosotros|mi|mis|tú|te|ti|tu|tus|ellas|nosotras|vosotros|vosotras|os|mío|mía|míos|mías|tuyo|tuya|tuyos|tuyas|suyo|suya|suyos|suyas|nuestro|nuestra|nuestros|nuestras|vuestro|vuestra|vuestros|vuestras|esos|esas|estoy|estás|está|estamos|estáis|están|esté|estés|estemos|estéis|estén|estaré|estarás|estará|estaremos|estaréis|estarán|estaba|estabas|estábamos|estabais|estaban|estuve|estuviste|estuvo|estuvimos|estuvisteis|estuvieron|estuviera|estuvieras|estuviéramos|estuvierais|estuvieran|estuviese|estuvieses|estuviésemos|estuvieseis|estuviesen|estando|estado|estada|estados|estadas|estad|he|has|ha|hemos|habéis|han|haya|hayas|hayamos|hayáis|hayan|habré|habrás|habrá|habremos|habréis|habrán|había|habías|habíamos|habíais|habían|hube|hubiste|hubo|hubimos|hubisteis|hubieron|hubiera|hubieras|hubiéramos|hubierais|hubieran|hubiese|hubieses|hubiésemos|hubieseis|hubiesen|habiendo|habido|habida|habidos|habidas|soy|eres|es|somos|sois|son|sea|seas|seamos|seáis|sean|seré|serás|será|seremos|seréis|serán|era|eras|éramos|erais|eran|fui|fuiste|fue|fuimos|fuisteis|fueron|fuera|fueras|fuéramos|fuerais|fueran|fuese|fueses|fuésemos|fueseis|fuesen|sintiendo|sentido|sentida|sentidos|sentidas|siente|sientes|sienten|sienta|sientas|sientan)\b/gi
    ];
    
    let englishScore = 0;
    let spanishScore = 0;
    
    // Count English patterns
    englishPatterns.forEach(pattern => {
      const matches = content.match(pattern);
      if (matches) {
        englishScore += matches.length;
      }
    });
    
    // Count Spanish patterns
    spanishPatterns.forEach(pattern => {
      const matches = content.match(pattern);
      if (matches) {
        spanishScore += matches.length;
      }
    });
    
    // If we have clear indicators, use them
    if (englishScore > 0 || spanishScore > 0) {
      return englishScore > spanishScore;
    }
    
    // Fallback: check for common English words
    const englishWords = ['the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'had', 'her', 'was', 'one', 'our', 'out', 'day', 'get', 'has', 'him', 'his', 'how', 'man', 'new', 'now', 'old', 'see', 'two', 'way', 'who', 'boy', 'did', 'its', 'let', 'put', 'say', 'she', 'too', 'use'];
    const words = content.toLowerCase().split(/\s+/);
    const englishWordCount = words.filter(word => englishWords.includes(word)).length;
    return englishWordCount > words.length * 0.05; // Lower threshold for better detection
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'completed':
        return '✅';
      case 'failed':
        return '❌';
      case 'processing':
        return '⏳';
      default:
        return '⏸️';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed':
        return 'green';
      case 'failed':
        return 'red';
      case 'processing':
        return 'orange';
      default:
        return 'gray';
    }
  };

  const hasProcessingJobs = jobs.some(job => job.status === 'processing');
  
  // Check for language mismatches
  const jobsWithLanguageMismatch = jobs.filter(job => 
    job.status === 'completed' && job.result && 
    ((isContentInEnglish(job.result) && i18n.language === 'es') || 
     (!isContentInEnglish(job.result) && i18n.language === 'en'))
  );

  if (loading && jobs.length === 0) {
    return <div>{t('processingStatus.loading')}</div>;
  }

  return (
    <div className="processing-status">
      <h3>{t('processingStatus.title')}</h3>
      
      {/* Language mismatch notification */}
      {jobsWithLanguageMismatch.length > 0 && (
        <div className="language-mismatch-alert">
          <div className="alert-header">
            <span className="alert-icon">🌐</span>
            <span className="alert-title">{t('processingStatus.languageMismatchTitle')}</span>
          </div>
          <p>{t('processingStatus.languageMismatchDescription')}</p>
          <div className="alert-actions">
            {jobsWithLanguageMismatch.map(job => (
              <button
                key={job.id}
                onClick={() => handleTranslateResult(job.job_type)}
                disabled={translatingJobs.has(job.job_type)}
                className="translate-all-button"
              >
                {translatingJobs.has(job.job_type) ? (
                  '🔄 Traduciendo...'
                ) : (
                  <>
                    {i18n.language === 'es' ? '🇪🇸 Traducir ' : '🇺🇸 Translate '}
                    {t(`processingStatus.jobTypes.${job.job_type}`)}
                  </>
                )}
              </button>
            ))}
          </div>
        </div>
      )}
      
      {/* Video processing help */}
      {jobs.some(job => job.result && job.result.includes('Archivo de video')) && (
        <div className="video-help-alert">
          <div className="alert-header">
            <span className="alert-icon">🎥</span>
            <span className="alert-title">Procesamiento de Video Automático</span>
          </div>
          <p>El sistema está procesando automáticamente tu video. Esto incluye:</p>
          <ul style={{ marginLeft: '1rem', marginBottom: '1rem' }}>
            <li>🔄 Extracción de audio del video</li>
            <li>🎤 Transcripción automática con IA</li>
            <li>📝 Análisis del contenido transcrito</li>
            <li>📋 Generación de propuestas y tickets</li>
          </ul>
          <p><strong>⏱️ Tiempo estimado:</strong> 2-5 minutos dependiendo de la duración del video</p>
          <div className="alert-actions">
            <button
              onClick={() => {
                // Crear un input file oculto para subir transcripción
                const input = document.createElement('input');
                input.type = 'file';
                input.accept = '.txt,.doc,.docx';
                input.onchange = (e) => {
                  const file = (e.target as HTMLInputElement).files?.[0];
                  if (file) {
                    // Aquí podrías implementar la lógica para procesar la transcripción
                    alert('Función de transcripción manual en desarrollo. El sistema está procesando automáticamente tu video.');
                  }
                };
                input.click();
              }}
              className="translate-all-button"
            >
              📝 Subir Transcripción Manual
            </button>
            <a
              href="https://otter.ai"
              target="_blank"
              rel="noopener noreferrer"
              className="translate-all-button"
              style={{ textDecoration: 'none', display: 'inline-block' }}
            >
              🎯 Usar Otter.ai (Alternativa)
            </a>
            <a
              href="https://docs.google.com"
              target="_blank"
              rel="noopener noreferrer"
              className="translate-all-button"
              style={{ textDecoration: 'none', display: 'inline-block' }}
            >
              📄 Google Docs (Alternativa)
            </a>
          </div>
        </div>
      )}
      
      {/* Action buttons for additional processing */}
      <div className="additional-actions">
        <h4>{t('processingStatus.additionalActions')}</h4>
        <div className="action-buttons">
          <button
            onClick={() => handleProcessContent('proposal')}
            disabled={processingAction === 'proposal' || hasProcessingJobs}
            className="action-button proposal"
          >
            {processingAction === 'proposal' ? t('meetingActions.generating') : t('meetingActions.generateProposal')}
          </button>
          
          <button
            onClick={() => handleProcessContent('jira_ticket')}
            disabled={processingAction === 'jira_ticket' || hasProcessingJobs}
            className="action-button jira"
          >
            {processingAction === 'jira_ticket' ? t('meetingActions.generating') : t('meetingActions.generateJiraTickets')}
          </button>
          
          <button
            onClick={() => handleProcessContent('executive_summary')}
            disabled={processingAction === 'executive_summary' || hasProcessingJobs}
            className="action-button executive"
          >
            {processingAction === 'executive_summary' ? t('meetingActions.generating') : t('meetingActions.generateExecutiveSummary')}
          </button>
        </div>
      </div>

      {/* Jobs list */}
      <div className="jobs-list">
        {jobs.length === 0 ? (
          <div className="no-jobs">{t('processingStatus.noJobs')}</div>
        ) : (
          jobs.map((job) => (
            <div key={job.id} className={`job-item ${getStatusColor(job.status)}`}>
              <div className="job-header">
                <span className="status-icon">{getStatusIcon(job.status)}</span>
                <span className="job-type">
                  {t(`processingStatus.jobTypes.${job.job_type}`)}
                </span>
                <span className="status">{t(`processingStatus.statuses.${job.status}`)}</span>
              </div>
              
              {job.result && (
                <div className="job-result">
                  <div className="result-header">
                    <h4>{t('processingStatus.result')}</h4>
                    {job.status === 'completed' && (
                      <div className="translation-controls">
                        {isContentInEnglish(job.result) && i18n.language === 'es' && (
                          <button
                            onClick={() => handleTranslateResult(job.job_type)}
                            disabled={translatingJobs.has(job.job_type)}
                            className="translate-button"
                            title={t('processingStatus.translateToSpanish')}
                          >
                            {translatingJobs.has(job.job_type) ? (
                              '🔄 Traduciendo...'
                            ) : (
                              '🇪🇸 Traducir al Español'
                            )}
                          </button>
                        )}
                        {!isContentInEnglish(job.result) && i18n.language === 'en' && (
                          <button
                            onClick={() => handleTranslateResult(job.job_type)}
                            disabled={translatingJobs.has(job.job_type)}
                            className="translate-button"
                            title={t('processingStatus.translateToEnglish')}
                          >
                            {translatingJobs.has(job.job_type) ? (
                              '🔄 Translating...'
                            ) : (
                              '🇺🇸 Translate to English'
                            )}
                          </button>
                        )}
                        {/* Language mismatch indicator */}
                        {((isContentInEnglish(job.result) && i18n.language === 'es') || 
                          (!isContentInEnglish(job.result) && i18n.language === 'en')) && (
                          <div className="language-mismatch-warning">
                            ⚠️ {t('processingStatus.languageMismatch')}
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                  <pre>{job.result}</pre>
                </div>
              )}
              
              {job.status === 'failed' && (
                <div className="job-error">
                  <strong>{t('processingStatus.error')}</strong> {job.result}
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default ProcessingStatus;
