FROM ruby:3.2.2

# Install system dependencies
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

# Set working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install

# Copy the backend directory
COPY backend/ ./backend/

# Set working directory to backend
WORKDIR /app/backend

# Set environment variables
ENV RAILS_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true
ENV RAILS_LOG_TO_STDOUT=true

# Expose port
EXPOSE $PORT

# Start the application
CMD bundle exec rails server -p $PORT -e production
