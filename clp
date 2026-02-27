#!/bin/bash
# clp - Claude Prison wrapper script

set -e

# Configuration
IMAGE_NAME="claude-prison-env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_CONFIG_DIR="$HOME/.config/claude-prison"
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Initialize
mkdir -p "$CLAUDE_CONFIG_DIR"

# Build image if it doesn't exist
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo ">> Building Claude Prison Docker image ($IMAGE_NAME)..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

# Set up volume mounts
VOLUMES=(
    "-v" "$PWD:/workspace"
    "-v" "$CLAUDE_CONFIG_DIR:/claude"
)

# Mount gitconfig if it exists
if [ -f "$HOME/.gitconfig" ]; then
    VOLUMES+=("-v" "$HOME/.gitconfig:/home/claude/.gitconfig:ro")
fi

# Use SSH Agent Forwarding instead of mounting ~/.ssh keys
if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    VOLUMES+=("-v" "$SSH_AUTH_SOCK:/tmp/ssh-agent")
    export SSH_AUTH_SOCK_CONTAINER="/tmp/ssh-agent"
else
    echo ">> Warning: SSH_AUTH_SOCK is not set or invalid. Git SSH operations may fail inside the container."
    echo ">> Tip: Start ssh-agent and add your keys (e.g., 'eval \$(ssh-agent)' and 'ssh-add ~/.ssh/id_ed25519')"
fi

# Mount Docker socket if it exists so Claude can run Docker commands
if [ -S "/var/run/docker.sock" ]; then
    VOLUMES+=("-v" "/var/run/docker.sock:/var/run/docker.sock")
fi

echo ">> Starting Claude Code in Prison (isolated container)..."

# Base docker run parameters
DOCKER_CMD=(docker run -it --rm
    --name "claude-prison-session"
    "${VOLUMES[@]}"
    -e USER_UID="$HOST_UID"
    -e USER_GID="$HOST_GID"
    -e CLAUDE_CONFIG_DIR="/claude"
)

# Forward SSH Agent socket if available
if [ -n "$SSH_AUTH_SOCK_CONTAINER" ]; then
    DOCKER_CMD+=("-e" "SSH_AUTH_SOCK=$SSH_AUTH_SOCK_CONTAINER")
fi

# Run the container
"${DOCKER_CMD[@]}" "$IMAGE_NAME" claude --dangerously-skip-permissions "$@"
