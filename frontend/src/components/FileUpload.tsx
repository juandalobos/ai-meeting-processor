import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { meetingsApi } from '../services/api';
import { Meeting } from '../types';

interface FileUploadProps {
  onMeetingCreated: (meeting: Meeting) => void;
}

const FileUpload: React.FC<FileUploadProps> = ({ onMeetingCreated }) => {
  const { t } = useTranslation();
  const [title, setTitle] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = event.target.files?.[0];
    if (selectedFile) {
      setFile(selectedFile);
      setError('');
    }
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();

    if (!file) {
      setError(t('fileUpload.noFileError'));
      return;
    }

    setLoading(true);
    setError('');

    try {
      const formData = new FormData();
      formData.append('meeting[title]', title || 'Untitled Meeting');
      formData.append('meeting[file]', file);

      const meeting = await meetingsApi.create(formData);

      onMeetingCreated(meeting);
      
      // Reset form
      setTitle('');
      setFile(null);
      const fileInput = document.getElementById('file-input') as HTMLInputElement;
      if (fileInput) fileInput.value = '';
      
    } catch (err: any) {
      console.error('Error creating meeting:', err);
      
      let errorMessage = t('fileUpload.error');
      
      if (err.response?.data?.errors) {
        errorMessage = Array.isArray(err.response.data.errors) 
          ? err.response.data.errors.join(', ')
          : err.response.data.errors;
      } else if (err.message) {
        errorMessage = err.message;
      }
      
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="file-upload">
      <h2>{t('fileUpload.title')}</h2>
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="title">{t('fileUpload.meetingTitle')}</label>
          <input
            type="text"
            id="title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder={t('fileUpload.meetingTitlePlaceholder')}
          />
          <small>{t('fileUpload.description')}</small>
        </div>

        <div className="form-group">
          <label htmlFor="file-input">{t('fileUpload.selectFile')}</label>
          <input
            type="file"
            id="file-input"
            onChange={handleFileChange}
            accept="audio/*,video/*,text/*,.txt,.doc,.docx,.pdf"
            required
          />
          <small>{t('fileUpload.supportedFormats')}</small>
        </div>

        {error && <div className="error">{error}</div>}

        <button type="submit" disabled={loading}>
          {loading ? t('fileUpload.uploading') : t('fileUpload.uploadButton')}
        </button>
      </form>
    </div>
  );
};

export default FileUpload;
