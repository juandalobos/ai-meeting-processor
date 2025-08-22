class BusinessContext < ApplicationRecord
  validates :name, presence: true
  validates :content, presence: true
  validates :context_type, presence: true, inclusion: { in: %w[template knowledge_base] }
  
  enum :context_type, {
    template: 'template',
    knowledge_base: 'knowledge_base'
  }
  
  scope :templates, -> { where(context_type: 'template') }
  scope :knowledge_base, -> { where(context_type: 'knowledge_base') }
end
