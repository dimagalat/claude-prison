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

# ---- Skills Dependencies ----
# The Makefile copies ~/.claude/skills to a local .tmp-skills context for build.
ARG INSTALL_SKILLS=""
COPY .tmp-skills/ /skills/
<<<<<<< HEAD
COPY install-skills.sh /usr/local/bin/install-skills.sh
RUN chmod +x /usr/local/bin/install-skills.sh && \
    if [ -n "$INSTALL_SKILLS" ]; then \
        apt-get update && apt-get install -y --no-install-recommends python3 python3-pip && rm -rf /var/lib/apt/lists/* && \
        if [ "$INSTALL_SKILLS" = "all" ]; then \
            /usr/local/bin/install-skills.sh; \
        else \
            /usr/local/bin/install-skills.sh $INSTALL_SKILLS; \
=======
RUN if [ -n "$INSTALL_SKILLS" ]; then \
        apt-get update && apt-get install -y --no-install-recommends python3 python3-pip && rm -rf /var/lib/apt/lists/* && \
        if [ -f "/skills/install-skills.sh" ]; then \
            chmod +x /skills/install-skills.sh && \
            if [ "$INSTALL_SKILLS" = "all" ]; then \
                /skills/install-skills.sh; \
            else \
                /skills/install-skills.sh $INSTALL_SKILLS; \
            fi; \
        else \
            echo ">> Warning: install-skills.sh not found in skill bundle!"; \
>>>>>>> 41684a1ddcd660a1b95ef51ec8996cf5d2d0135d
        fi && \
        if [ -f "/skills/env.sh" ]; then \
            mv /skills/env.sh /etc/profile.d/skills-env.sh; \
        fi \
    fi && \
<<<<<<< HEAD
    # Cleanup temporary skills directory since clp mounts them at runtime anyway
    rm -rf /skills
=======
    # Cleanup skills files from image since clp mounts them at runtime anyway
    rm -rf /skills/*
>>>>>>> 41684a1ddcd660a1b95ef51ec8996cf5d2d0135d
# Copy local entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set working directory
WORKDIR /workspace

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["sh", "-c", "echo 'Claude Code container is ready!'"]
