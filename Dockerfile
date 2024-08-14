# Use Ubuntu base image
FROM ubuntu:latest

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev nodejs wget curl unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Ruby
RUN apt-get update -qq && \
    apt-get install -y ruby-full && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install MySQL client
RUN apt-get update && \
    apt-get install -y mysql-client && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    sudo ./aws/install && \
    rm awscliv2.zip

# Set the working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby gems
RUN gem install bundler && bundle install

# Copy the application code
COPY . .

# Run the backup script
CMD ["ruby", "backup.rb"]