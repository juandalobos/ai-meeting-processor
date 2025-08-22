# Create sample business contexts
BusinessContext.create!(
  name: 'Proposal Template',
  content: 'This is a template for generating business proposals. Include executive summary, problem statement, solution, timeline, and budget.',
  context_type: 'template'
)

BusinessContext.create!(
  name: 'Jira Template',
  content: 'Template for generating Jira tickets. Include epic, stories, tasks with proper priority and acceptance criteria.',
  context_type: 'template'
)

BusinessContext.create!(
  name: 'Company Knowledge Base',
  content: 'Our company specializes in software development and consulting services. We focus on agile methodologies and modern technologies.',
  context_type: 'knowledge_base'
)

BusinessContext.create!(
  name: 'Project Standards',
  content: 'All projects must follow our coding standards, include proper documentation, and have comprehensive testing.',
  context_type: 'knowledge_base'
)

puts "Sample business contexts created successfully!"
