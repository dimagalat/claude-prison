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
    groupadd -g "$USER_GID" claude_group 2>/dev/null || true
    GROUP_NAME="claude_group"
else
    # GID exists, grab its name
    GROUP_NAME=$(getent group "$USER_GID" | cut -d: -f1)
fi

# Ensure the user exists
# We check if a user with the given UID already exists. If not, we create 'claude_user'.
if ! getent passwd "$USER_UID" >/dev/null 2>&1; then
    useradd -u "$USER_UID" -g "$GROUP_NAME" -d /home/claude -s /bin/sh -m claude_user 2>/dev/null || true
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
        if gosu "${USER_NAME}" ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>&1 | grep -q "successfully authenticated"; then
            echo ">> [SSH Agent] Success: Container is authenticated with GitHub!"
        else
            echo ">> [SSH Agent] Warning: Container failed GitHub SSH authentication."
            echo ">> [SSH Agent] Check if your key is authorized for this repo on GitHub."
        fi
    fi
fi

# Set up Claude Auth / Subscription directly in the container's HOME
# Using a dedicated volume /claude-persist mapped from Docker instead of host mount
PERSISTENT_CREDS="/claude-persist/.credentials.json"
FALLBACK_MAC_CREDS="/claude/.credentials.json"
CONTAINER_CLAUDE_DIR="${USER_HOME}/.claude"
CONTAINER_CREDS="${CONTAINER_CLAUDE_DIR}/.credentials.json"
CONTAINER_AUTH="${USER_HOME}/.claude.json"

mkdir -p "$CONTAINER_CLAUDE_DIR"
chown "$USER_UID:$USER_GID" "$CONTAINER_CLAUDE_DIR" 2>/dev/null || true

# Restore credentials if they exist
if [ -f "$PERSISTENT_CREDS" ]; then
    echo ">> [Claude Auth] Restoring credentials from persistent volume..."
    cp "$PERSISTENT_CREDS" "$CONTAINER_CREDS"
elif [ -f "$FALLBACK_MAC_CREDS" ]; then
    echo ">> [Claude Auth] Restoring credentials from Mac Keychain fallback..."
    cp "$FALLBACK_MAC_CREDS" "$CONTAINER_CREDS"
else
    echo ">> [Claude Auth] Warning: No authentication state found. You may need to log in."
fi

# Ensure correct ownership of credentials
if [ -f "$CONTAINER_CREDS" ]; then
    chown "$USER_UID:$USER_GID" "$CONTAINER_CREDS" 2>/dev/null || true
    chmod 600 "$CONTAINER_CREDS" 2>/dev/null || true
fi

# Generate minimal .claude.json so it doesn't think it's a fresh install
# This prevents the re-auth loop caused by missing .claude.json even when credentials exist
echo '{"hasCompletedOnboarding":true,"installMethod":"native"}' > "$CONTAINER_AUTH"
chown "$USER_UID:$USER_GID" "$CONTAINER_AUTH" 2>/dev/null || true

# Source skill environment variables if any skills were installed
if [ -f /etc/profile.d/skills-env.sh ]; then
    . /etc/profile.d/skills-env.sh
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

# Set up a trap to save credentials back to the persistent volume when the container exits
save_credentials() {
    if [ -f "$CONTAINER_CREDS" ]; then
        cp "$CONTAINER_CREDS" "$PERSISTENT_CREDS" 2>/dev/null || true
    fi
}
trap save_credentials EXIT

# Execute the command (without exec so the trap fires on exit)
gosu "${USER_NAME}" "$@"
EXIT_CODE=$?

exit $EXIT_CODE
