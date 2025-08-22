#!/bin/bash

echo "🚀 Deploying AI Meeting Processor to Production..."

# Check if we're in the right directory
if [ ! -f "start.sh" ]; then
    echo "❌ Please run this script from the project root directory"
    exit 1
fi

# Check if .env files exist
if [ ! -f "backend/.env" ]; then
    echo "📝 Creating backend .env file..."
    cat > backend/.env << 'ENVEOF'
# Google Gemini API Key
GEMINI_API_KEY=AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0

# Database Configuration
DATABASE_URL=postgresql://postgres:password@localhost:5432/ai_meeting_processor

# Redis Configuration (for Sidekiq)
REDIS_URL=redis://localhost:6379/0

# Rails Environment
RAILS_ENV=production
SECRET_KEY_BASE=$(bundle exec rails secret)
ENVEOF
fi

echo "✅ Environment files configured"

# Install dependencies
echo "📦 Installing backend dependencies..."
cd backend
bundle install --deployment
bundle exec rails assets:precompile
bundle exec rails db:migrate RAILS_ENV=production

echo "📦 Installing frontend dependencies..."
cd ../frontend
npm install --production
npm run build

echo ""
echo "🎉 Deployment completed!"
echo ""
echo "To start the application in production:"
echo "1. Start PostgreSQL and Redis"
echo "2. Run: ./start.sh"
echo ""
echo "Or use Docker:"
echo "docker-compose up --build"
