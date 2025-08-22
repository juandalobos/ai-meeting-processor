class Meeting < ApplicationRecord
  has_one_attached :file
  has_many :processing_jobs, dependent: :destroy
  
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  
  enum :status, {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }
  
  def file_type
    return nil unless file.attached?
    
    case file.content_type
    when /^audio\//
      'audio'
    when /^video\//
      'video'
    when /^text\//
      'text'
    else
      'unknown'
    end
  end
end
