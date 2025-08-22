export interface Meeting {
  id: number;
  title: string;
  description?: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  created_at: string;
  updated_at: string;
  processing_jobs: ProcessingJob[];
}

export interface BusinessContext {
  id: number;
  name: string;
  content: string;
  context_type: 'template' | 'knowledge_base';
  created_at: string;
  updated_at: string;
}

export interface ProcessingJob {
  id: number;
  meeting_id: number;
  job_type: 'proposal' | 'jira_ticket' | 'executive_summary';
  status: 'pending' | 'processing' | 'completed' | 'failed';
  result?: string;
  created_at: string;
  updated_at: string;
}

export interface ApiResponse<T> {
  data?: T;
  error?: string;
  message?: string;
}
