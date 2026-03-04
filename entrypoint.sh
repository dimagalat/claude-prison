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

# Determine the actual home directory for the user
USER_HOME=$(getent passwd "${USER_NAME}" | cut -d: -f6)
export HOME="${USER_HOME}"

# Ensure configurations and workspace are accessible
if [ -d /claude ]; then
    chown "$USER_UID:$USER_GID" /claude 2>/dev/null || true
fi

# Link Git and SSH configs from neutral mount points
if [ -f "/claude/.gitconfig" ]; then
    ln -sf "/claude/.gitconfig" "${USER_HOME}/.gitconfig"
    chown -h "$USER_UID:$USER_GID" "${USER_HOME}/.gitconfig" 2>/dev/null || true
fi

mkdir -p "${USER_HOME}/.ssh"
if [ -f "/claude/.ssh_known_hosts" ]; then
    ln -sf "/claude/.ssh_known_hosts" "${USER_HOME}/.ssh/known_hosts"
    chown -h "$USER_UID:$USER_GID" "${USER_HOME}/.ssh/known_hosts" 2>/dev/null || true
fi

if [ -f "/claude/.ssh_config" ]; then
    ln -sf "/claude/.ssh_config" "${USER_HOME}/.ssh/config"
    chown -h "$USER_UID:$USER_GID" "${USER_HOME}/.ssh/config" 2>/dev/null || true
fi
chown -R "$USER_UID:$USER_GID" "${USER_HOME}/.ssh" 2>/dev/null || true
chmod 700 "${USER_HOME}/.ssh"

# Ensure the SSH agent socket is accessible by the mapped user
if [ -S "$SSH_AUTH_SOCK" ]; then
    chown "$USER_UID:$USER_GID" "$SSH_AUTH_SOCK" 2>/dev/null || true
    chmod 666 "$SSH_AUTH_SOCK" 2>/dev/null || true
    echo ">> [SSH Agent] Socket detected: $SSH_AUTH_SOCK"
else
    echo ">> [SSH Agent] Warning: No socket found at $SSH_AUTH_SOCK"
fi

# Quick key check for diagnostics (as root first, then as the mapped user)
if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    NUM_KEYS=$(ssh-add -l 2>/dev/null | grep -cv "no identities" || true)
    if [ "$NUM_KEYS" -eq 0 ]; then
        echo ">> [SSH Agent] Status: Connected, but NO KEYS found in agent."
        echo ">> [SSH Agent] Tip: Run 'ssh-add' on your Mac before starting 'clp'."
    else
        echo ">> [SSH Agent] Status: Connected with $NUM_KEYS key(s) available."
        echo ">> [SSH Agent] Verifying GitHub connectivity from inside..."
        # Try a quick non-interactive test as the mapped user
        if su-exec "${USER_NAME}" ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>&1 | grep -q "successfully authenticated"; then
            echo ">> [SSH Agent] Success: Container is authenticated with GitHub!"
        else
            echo ">> [SSH Agent] Warning: Container failed GitHub SSH authentication."
            echo ">> [SSH Agent] Check if your key is authorized for this repo on GitHub."
        fi
    fi
fi

# Set up Claude Auth / Subscription via persistent symlinks
# This allows Claude Code to write refreshed tokens and session state back to the host-mounted config dir
PERSISTENT_CLAUDE_DIR="/claude/.claude"
CONTAINER_CLAUDE_DIR="${USER_HOME}/.claude"
PERSISTENT_AUTH="/claude/.claude.json"
CONTAINER_AUTH="${USER_HOME}/.claude.json"

if [ -d "$PERSISTENT_CLAUDE_DIR" ]; then
    echo ">> [Claude Auth] Establishing full session bridge in ${USER_HOME}..."
    ln -sf "$PERSISTENT_CLAUDE_DIR" "$CONTAINER_CLAUDE_DIR"
    chown -h "$USER_UID:$USER_GID" "$CONTAINER_CLAUDE_DIR" 2>/dev/null || true
fi

if [ -f "$PERSISTENT_AUTH" ]; then
    ln -sf "$PERSISTENT_AUTH" "$CONTAINER_AUTH"
    chown -h "$USER_UID:$USER_GID" "$CONTAINER_AUTH" 2>/dev/null || true
    
    if grep -q "opusProMigrationComplete" "$CONTAINER_AUTH" 2>/dev/null; then
        echo ">> [Claude Auth] Subscription: Professional/Max features active."
    fi
fi

if [ ! -d "$PERSISTENT_CLAUDE_DIR" ] && [ ! -f "$PERSISTENT_AUTH" ]; then
    echo ">> [Claude Auth] Warning: No authentication state found in /claude. You may be in guest mode."
fi

export SHELL=/bin/bash

# Force-override "native" install expectation
# The host session expects Claude at `~/.local/bin/claude`. We symlink the container's
# global npm installation there to satisfy the requirement and bypass the auto-updater crash.
if [ -f "/usr/local/bin/claude" ]; then
    mkdir -p "${USER_HOME}/.local/bin"
    ln -sf "/usr/local/bin/claude" "${USER_HOME}/.local/bin/claude"
    chown -R "$USER_UID:$USER_GID" "${USER_HOME}/.local" 2>/dev/null || true
    # Also add it to front of path just in case
    export PATH="${USER_HOME}/.local/bin:$PATH"
fi

# Switch from root to the mapped user and execute the passed command (e.g. `claude`)
exec su-exec "${USER_NAME}" "$@"
