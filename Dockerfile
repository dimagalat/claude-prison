# Use official Node.js Debian slim image (Alpine lacks glibc, breaking pip packages like playwright)
FROM node:22-slim

# Install minimal required tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    openssh-client \
    gosu \
    docker.io && \
    rm -rf /var/lib/apt/lists/* && \
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
