class ProcessingJob < ApplicationRecord
  belongs_to :meeting
  
  validates :job_type, presence: true, inclusion: { in: %w[proposal jira_ticket executive_summary] }
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  
  enum :job_type, {
    proposal: 'proposal',
    jira_ticket: 'jira_ticket',
    executive_summary: 'executive_summary'
  }
  
  enum :status, {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }
end
