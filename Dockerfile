# Use official Node.js Alpine image
FROM node:22-alpine

# Install minimal required tools
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    git \
    openssh-client \
    python3 \
    py3-pillow \
    su-exec \
    docker-cli && \
    npm install -g npm@latest

# Silence npm update notices
ENV NO_UPDATE_NOTIFIER=true

# Install Claude Code globally and safely hot-patch the broken OAuth scopes
# We pin to 2.1.68 and apply a core-level surgical patch to repair the scope array.
COPY patch.js /tmp/patch.js
RUN npm install -g @anthropic-ai/claude-code@2.1.68 && \
    node /tmp/patch.js && \
    rm /tmp/patch.js

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
