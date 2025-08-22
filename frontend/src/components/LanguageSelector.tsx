import React from 'react';
import { useTranslation } from 'react-i18next';

interface LanguageSelectorProps {
  meetingId?: number;
  onLanguageChange?: (language: string) => void;
}

const LanguageSelector: React.FC<LanguageSelectorProps> = ({ meetingId, onLanguageChange }) => {
  const { i18n, t } = useTranslation();

  const changeLanguage = async (lng: string) => {
    console.log('=== LanguageSelector changeLanguage called ===');
    console.log('Language:', lng);
    console.log('MeetingId:', meetingId);
    console.log('onLanguageChange exists:', !!onLanguageChange);
    
    i18n.changeLanguage(lng);
    
    // Si hay un meetingId y onLanguageChange, intentar traducir automáticamente
    if (meetingId && onLanguageChange) {
      console.log('Calling onLanguageChange with:', lng);
      onLanguageChange(lng);
    } else {
      console.log('Not calling onLanguageChange - missing meetingId or callback');
    }
  };

  return (
    <div className="language-selector">
      <span className="language-label">{t('languageSelector.title')}:</span>
      <div className="language-buttons">
        <button
          className={`language-btn ${i18n.language === 'es' ? 'active' : ''}`}
          onClick={() => changeLanguage('es')}
        >
          🇪🇸 {t('languageSelector.spanish')}
        </button>
        <button
          className={`language-btn ${i18n.language === 'en' ? 'active' : ''}`}
          onClick={() => changeLanguage('en')}
        >
          🇺🇸 {t('languageSelector.english')}
        </button>
      </div>
    </div>
  );
};

export default LanguageSelector;
