FROM node:13-alpine

# Install dependencies
RUN apk update && apk add --no-cache bash curl mongodb-client cron

# Create a directory for the scripts
RUN mkdir -p /home/app/scripts

# Copy the app and the scripts into the container
COPY ./app /home/app
COPY ./scripts/domain_health_check.sh /home/app/scripts/domain_health_check.sh

# Set working directory
WORKDIR /home/app

# Set environment variables
ENV MONGO_URL="mongodb://admin:password@mongodb:27017"
ENV DATABASE="domain_monitor"
ENV COLLECTION="domains"

# Give execution permission to the script
RUN chmod +x /home/app/scripts/domain_health_check.sh

# Add cron job to run the script every day at midnight (adjust as needed)
RUN echo "0 0 * * * /home/app/scripts/domain_health_check.sh" >> /etc/crontabs/root

# Start cron and your application
CMD crond && node server.js
