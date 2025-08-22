#!/bin/bash

echo "�� Starting AI Meeting Processor with Gemini API..."

# Check if .env file exists in backend
if [ ! -f "backend/.env" ]; then
    echo "📝 Creating .env file with Gemini API key..."
    cat > backend/.env << 'ENVEOF'
# Google Gemini API Key
GEMINI_API_KEY=AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0

# Database Configuration
DATABASE_URL=postgresql://postgres:password@localhost:5432/ai_meeting_processor

# Redis Configuration (for Sidekiq)
REDIS_URL=redis://localhost:6379/0

# Rails Environment
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key_base_here
ENVEOF
    echo "✅ .env file created with Gemini API key"
fi

# Start backend
echo "📦 Starting Backend..."
cd backend
bundle install
bundle exec rails db:create db:migrate db:seed
bundle exec rails server -p 3001 &
BACKEND_PID=$!

# Wait for backend to start
echo "⏳ Waiting for backend to start..."
sleep 5

# Test backend health
if curl -s http://localhost:3001/up > /dev/null; then
    echo "✅ Backend is running on http://localhost:3001"
else
    echo "❌ Backend failed to start"
    exit 1
fi

# Start frontend
echo "🎨 Starting Frontend..."
cd ../frontend
npm install
npm start &
FRONTEND_PID=$!

echo ""
echo "🎉 Application started successfully!"
echo "Frontend: http://localhost:3000"
echo "Backend API: http://localhost:3001"
echo "Gemini API: ✅ Configured and ready"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait for user to stop
wait

# Cleanup
echo "🛑 Stopping services..."
kill $BACKEND_PID $FRONTEND_PID 2>/dev/null
echo "✅ Services stopped"
