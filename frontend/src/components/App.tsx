import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import FileUpload from './FileUpload';
import MeetingActions from './MeetingActions';
import ProcessingStatus from './ProcessingStatus';
import LanguageSelector from './LanguageSelector';
import { Meeting } from '../types';
import { meetingsApi } from '../services/api';

const App: React.FC = () => {
  const { t } = useTranslation();
  const [currentMeeting, setCurrentMeeting] = useState<Meeting | null>(null);
  const [showStatus, setShowStatus] = useState(false);

  const handleMeetingCreated = (meeting: Meeting) => {
    setCurrentMeeting(meeting);
    setShowStatus(false);
  };

  const handleProcessingStarted = () => {
    setShowStatus(true);
  };

  const handleNewMeeting = () => {
    setCurrentMeeting(null);
    setShowStatus(false);
  };

  const handleLanguageChange = async (language: string) => {
    if (!currentMeeting) {
      return;
    }
    
    try {
      // Intentar traducir todos los jobs existentes
      const jobs = currentMeeting.processing_jobs || [];
      const updatedJobs = [...jobs];
      
      for (let i = 0; i < jobs.length; i++) {
        const job = jobs[i];
        
        if (job.result) {
          const response = await meetingsApi.translateResult(currentMeeting.id, job.job_type, language);
          
          if (response && response.result) {
            updatedJobs[i] = { ...job, result: response.result };
          }
        }
      }
      
      // Actualizar el estado del meeting con los jobs traducidos
      setCurrentMeeting({
        ...currentMeeting,
        processing_jobs: updatedJobs
      });
      
    } catch (error) {
      console.error('Error translating results:', error);
    }
  };

  return (
    <div className="app">
      <header className="app-header">
        <div className="header-content">
          <div className="logo-section">
            <img src="/logo.svg" alt="SOMOS Logo" className="logo" />
            <div className="title-section">
              <h1>{t('app.title')}</h1>
              <p>{t('app.subtitle')}</p>
            </div>
          </div>
          <LanguageSelector 
            meetingId={currentMeeting?.id} 
            onLanguageChange={handleLanguageChange}
          />
        </div>
      </header>

      <main className="app-main">
        {!currentMeeting ? (
          <FileUpload onMeetingCreated={handleMeetingCreated} />
        ) : (
          <div className="meeting-workflow">
            <div className="meeting-info">
              <h2>{t('meetingInfo.meeting')}: {currentMeeting.title}</h2>
              <p>{t('meetingInfo.status')}: {currentMeeting.status}</p>
              {currentMeeting.description && (
                <p>{t('meetingInfo.description')}: {currentMeeting.description}</p>
              )}
              <button onClick={handleNewMeeting} className="new-meeting-btn">
                {t('meetingInfo.uploadNewMeeting')}
              </button>
            </div>

            {!showStatus ? (
              <MeetingActions 
                meeting={currentMeeting} 
                onProcessingStarted={handleProcessingStarted} 
              />
            ) : (
              <ProcessingStatus 
                meetingId={currentMeeting.id} 
                onStatusChange={() => {}} 
                onNewProcessingStarted={handleProcessingStarted}
              />
            )}
          </div>
        )}
      </main>
    </div>
  );
};

export default App;
