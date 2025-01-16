FROM node:13-alpine

# Install dependencies
RUN apk update && apk add --no-cache bash curl mongodb-client cron

# Create a directory for the scripts
RUN mkdir -p /home/app/scripts

# Copy your app files into the container
COPY ./app /home/app

# Copy your scripts into the container
COPY scripts/ /scripts/

# Grant execute permission to all scripts in the /scripts/ directory
RUN chmod +x /scripts/*


# Set working directory
WORKDIR /home/app

# Set environment variables
ENV MONGO_URL="mongodb://admin:password@mongodb:27017"
ENV DATABASE="domain_monitor"
ENV COLLECTION="domains"

# Add cron job to run the script every day at midnight (adjust as needed)
RUN echo "0 0 * * * /home/app/scripts/domain-check.sh" >> /etc/crontabs/root

# Start cron and your application
CMD crond && node server.js
