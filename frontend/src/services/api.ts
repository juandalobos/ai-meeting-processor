import axios from 'axios';
import { Meeting, BusinessContext, ProcessingJob, ApiResponse } from '../types';

const API_BASE_URL = 'http://localhost:3001/api';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Meetings API
export const meetingsApi = {
  getAll: async (): Promise<Meeting[]> => {
    const response = await api.get('/meetings');
    return response.data as Meeting[];
  },
  
  getById: async (id: number): Promise<Meeting> => {
    const response = await api.get(`/meetings/${id}`);
    return response.data as Meeting;
  },
  
  create: async (formData: FormData): Promise<Meeting> => {
    const response = await axios.post(`${API_BASE_URL}/meetings`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      timeout: 600000, // 10 minutos de timeout para archivos grandes
    });
    return response.data as Meeting;
  },
  
    processContent: async (id: number, jobType: 'proposal' | 'jira_ticket' | 'executive_summary', language: string = 'es'): Promise<ApiResponse<any>> => {
    // En desarrollo, usar modo síncrono para testing más rápido
    const isDev = process.env.NODE_ENV === 'development';
    const params = isDev ? { job_type: jobType, sync: 'true', language } : { job_type: jobType, language };

    const response = await api.post(`/meetings/${id}/process_content`, params);
    return response.data as ApiResponse<any>;
  },

  translateResult: async (id: number, jobType: 'proposal' | 'jira_ticket' | 'executive_summary', language: string): Promise<any> => {
    const response = await api.post(`/meetings/${id}/translate_result`, { job_type: jobType, language });
    return response.data;
  },
};

// Business Contexts API
export const businessContextsApi = {
  getAll: async (): Promise<BusinessContext[]> => {
    const response = await api.get('/business_contexts');
    return response.data as BusinessContext[];
  },
  
  getById: async (id: number): Promise<BusinessContext> => {
    const response = await api.get(`/business_contexts/${id}`);
    return response.data as BusinessContext;
  },
  
  create: async (context: Partial<BusinessContext>): Promise<BusinessContext> => {
    const response = await api.post('/business_contexts', { business_context: context });
    return response.data as BusinessContext;
  },
  
  update: async (id: number, context: Partial<BusinessContext>): Promise<BusinessContext> => {
    const response = await api.put(`/business_contexts/${id}`, { business_context: context });
    return response.data as BusinessContext;
  },
  
  delete: async (id: number): Promise<void> => {
    await api.delete(`/business_contexts/${id}`);
  },
};

// Processing Jobs API
export const processingJobsApi = {
  getAll: async (): Promise<ProcessingJob[]> => {
    const response = await api.get('/processing_jobs');
    return response.data as ProcessingJob[];
  },
  
  getById: async (id: number): Promise<ProcessingJob> => {
    const response = await api.get(`/processing_jobs/${id}`);
    return response.data as ProcessingJob;
  },
  
  getByMeeting: async (meetingId: number): Promise<ProcessingJob[]> => {
    const response = await api.get(`/processing_jobs/meeting_jobs?meeting_id=${meetingId}`);
    return response.data as ProcessingJob[];
  },
};

export default api;
