# Use official Node.js Alpine image
FROM node:22-alpine

# Install minimal required tools
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    git \
    openssh-client \
    su-exec \
    docker-cli && \
    npm install -g npm@latest

# Silence npm update notices
ENV NO_UPDATE_NOTIFIER=true

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code@latest

# Create directories
RUN mkdir -p /claude /workspace

# Copy local entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set working directory
WORKDIR /workspace

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["sh", "-c", "echo 'Claude Code container is ready!'"]
