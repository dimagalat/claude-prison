# Use official Node.js Alpine image
FROM node:22-alpine

# Install minimal required tools
RUN apk add --no-cache \
    bash \
    curl \
    git \
    openssh-client \
    python3 \
    py3-pillow \
    su-exec \
    docker-cli

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
