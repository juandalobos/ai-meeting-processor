#!/bin/bash

echo "🧪 Testing AI Meeting Processor..."

# Test 1: Check if backend .env exists
if [ -f "backend/.env" ]; then
    echo "✅ Backend .env file exists"
    if grep -q "AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0" backend/.env; then
        echo "✅ Gemini API key is configured"
    else
        echo "❌ Gemini API key not found in .env"
    fi
else
    echo "❌ Backend .env file missing"
fi

# Test 2: Check if database can be created
cd backend
if bundle exec rails db:create 2>/dev/null; then
    echo "✅ Database can be created"
else
    echo "⚠️  Database already exists or PostgreSQL not running"
fi

# Test 3: Check if migrations can run
if bundle exec rails db:migrate 2>/dev/null; then
    echo "✅ Database migrations successful"
else
    echo "❌ Database migrations failed"
fi

# Test 4: Test Gemini API
echo "🧪 Testing Gemini API integration..."
if ruby test_gemini.rb 2>/dev/null | grep -q "Gemini API is working correctly"; then
    echo "✅ Gemini API integration working"
else
    echo "❌ Gemini API integration failed"
fi

cd ..

echo ""
echo "🎯 Ready to start the application!"
echo "Run: ./start.sh"
