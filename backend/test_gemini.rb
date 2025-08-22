#!/usr/bin/env ruby

require 'bundler/setup'
require 'httparty'
require 'json'

# Test Gemini API integration
api_key = 'AIzaSyDJaGP1VFteHLU-eLFf-XzbA4sFGgd3if0'
model = 'models/gemini-1.5-flash'

puts "🧪 Testing Gemini API integration..."

begin
  response = HTTParty.post(
    "https://generativelanguage.googleapis.com/v1beta/#{model}:generateContent?key=#{api_key}",
    headers: { 'Content-Type' => 'application/json' },
    body: {
      contents: [{
        parts: [{
          text: "Hello! Please respond with 'Gemini API is working correctly' if you can see this message."
        }]
      }]
    }.to_json
  )

  if response.code == 200
    result = JSON.parse(response.body)
    if result['candidates']&.first&.dig('content', 'parts', 0, 'text')
      puts "✅ Gemini API is working correctly!"
      puts "Response: #{result['candidates'].first['content']['parts'][0]['text']}"
    else
      puts "❌ Unexpected response format"
      puts "Response: #{response.body}"
    end
  else
    puts "❌ API request failed with status: #{response.code}"
    puts "Response: #{response.body}"
  end
rescue => e
  puts "❌ Error testing Gemini API: #{e.message}"
end
