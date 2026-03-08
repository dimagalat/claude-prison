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

# Skills: SKILL.md files are always copied for reference. Dependencies are only
# installed when INSTALL_SKILLS is set.
#   docker build --build-arg INSTALL_SKILLS=all .
#   docker build --build-arg INSTALL_SKILLS="webapp-testing" .
ARG INSTALL_SKILLS=""
COPY skills/ /skills/
RUN if [ -n "$INSTALL_SKILLS" ]; then \
        apt-get update && apt-get install -y --no-install-recommends python3 python3-pip && rm -rf /var/lib/apt/lists/* && \
        chmod +x /skills/install-skills.sh && \
        if [ "$INSTALL_SKILLS" = "all" ]; then \
            /skills/install-skills.sh; \
        else \
            /skills/install-skills.sh $INSTALL_SKILLS; \
        fi; \
    fi

# Copy local entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set working directory
WORKDIR /workspace

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["sh", "-c", "echo 'Claude Code container is ready!'"]
