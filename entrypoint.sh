#!/bin/sh
set -e

# This is a standard Docker pattern to handle UID/GID mapping.
# It ensures that when Claude Code creates files in /workspace (the mounted host directory),
# the files belong to the user who ran the container instead of 'root'.

USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}

# If running as root (UID 0), no mapping is strictly necessary, execute normally
if [ "$USER_UID" -eq 0 ]; then
    exec "$@"
fi

# Ensure the group exists
# We check if a group with the given GID already exists. If not, we create 'claude_group'.
if ! getent group "$USER_GID" >/dev/null 2>&1; then
    addgroup -g "$USER_GID" claude_group 2>/dev/null || true
    GROUP_NAME="claude_group"
else
    # GID exists, grab its name
    GROUP_NAME=$(getent group "$USER_GID" | cut -d: -f1)
fi

# Ensure the user exists
# We check if a user with the given UID already exists. If not, we create 'claude_user'.
if ! getent passwd "$USER_UID" >/dev/null 2>&1; then
    adduser -D -u "$USER_UID" -G "$GROUP_NAME" -h /home/claude -s /bin/sh claude_user 2>/dev/null || true
    USER_NAME="claude_user"
else
    # UID exists, grab its name
    USER_NAME=$(getent passwd "$USER_UID" | cut -d: -f1)
fi

# Ensure configurations and workspace are accessible
if [ -d /claude ]; then
    chown "$USER_UID:$USER_GID" /claude 2>/dev/null || true
fi

export SHELL=/bin/bash

# Switch from root to the mapped user and execute the passed command (e.g. `claude`)
exec su-exec "${USER_NAME}" "$@"
