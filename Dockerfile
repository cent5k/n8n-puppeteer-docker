# Use Node 16 Alpine as base image
FROM node:16-alpine

# Declare argument for n8n version
ARG N8N_VERSION

# Check if N8N_VERSION is set
RUN if [ -z "$N8N_VERSION" ] ; then echo "The N8N_VERSION argument is missing!" ; exit 1; fi

# Update packages and install required dependencies
RUN apk add --update graphicsmagick tzdata git tini su-exec

# Set user to root (in this context, it's just making it explicit since it's the default)
USER root

# Install n8n with required build tools and cleanup after
RUN apk --update add --virtual build-dependencies python3 build-base ca-certificates && \
	npm config set python "$(which python3)" && \
	npm_config_user=root npm install -g full-icu n8n@${N8N_VERSION} && \
	apk del build-dependencies && \
	rm -rf /root /tmp/* /var/cache/apk/* && mkdir /root;

# Install Chromium and related packages
RUN apk add --no-cache \
      chromium \
      nss \
      freetype \
      harfbuzz \
      ttf-freefont \
      yarn

# Configure Puppeteer to use the installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Install n8n's puppeteer nodes
RUN cd /usr/local/lib/node_modules/n8n && npm install n8n-nodes-puppeteer

# Install Microsoft core fonts and clean up
RUN apk --no-cache add --virtual fonts msttcorefonts-installer fontconfig && \
	update-ms-fonts && \
	fc-cache -f && \
	apk del fonts && \
	find /usr/share/fonts/truetype/msttcorefonts/ -type l -exec unlink {} \; && \
	rm -rf /root /tmp/* /var/cache/apk/* && mkdir /root

# Set ICU data environment variable for Node.js
ENV NODE_ICU_DATA /usr/local/lib/node_modules/full-icu

# Set working directory inside the container
WORKDIR /data

# Copy the entrypoint script to the container
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Ensure the script has execute permissions
RUN chmod +x /docker-entrypoint.sh

# Set the entrypoint command for the container
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

# Expose port 5678 for n8n's web interface
EXPOSE 5678/tcp
