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

# Mount known_hosts to prevent verification prompts
if [ -f "$HOME/.ssh/known_hosts" ]; then
    VOLUMES+=("-v" "$HOME/.ssh/known_hosts:/home/claude/.ssh/known_hosts:ro")
fi

# Use SSH Agent Forwarding instead of mounting ~/.ssh keys
if [ -n "$SSH_AUTH_SOCK" ]; then
    # Resolve potential symlinks (common on macOS /tmp -> /private/tmp)
    RESOLVED_SOCKET=$(python3 -c "import os; print(os.path.realpath('$SSH_AUTH_SOCK'))")
    if [ -S "$RESOLVED_SOCKET" ]; then
        VOLUMES+=("-v" "$RESOLVED_SOCKET:/tmp/ssh-agent")
        export SSH_AUTH_SOCK_CONTAINER="/tmp/ssh-agent"
    else
        echo ">> Warning: SSH_AUTH_SOCK ($SSH_AUTH_SOCK) resolved to $RESOLVED_SOCKET but it's not a valid socket."
    fi
else
    echo ">> Warning: SSH_AUTH_SOCK is not set. Git SSH operations may fail inside the container."
    echo ">> Tip: Start ssh-agent and add your keys (e.g., 'eval \$(ssh-agent)' and 'ssh-add <your-key>')"
fi

# Mount Docker socket if it exists so Claude can run Docker commands
if [ -S "/var/run/docker.sock" ]; then
    VOLUMES+=("-v" "/var/run/docker.sock:/var/run/docker.sock")
fi

if [ -n "$SSH_AUTH_SOCK_CONTAINER" ]; then
    KEY_COUNT=$(ssh-add -l 2>/dev/null | grep -cv "no identities" || true)
    if [ "$KEY_COUNT" -eq 0 ]; then
        echo ">> Warning: Your ssh-agent is running but has NO KEYS loaded."
        # Discover available private keys in ~/.ssh
        AVAILABLE_KEYS=()
        for f in "$HOME"/.ssh/id_*; do
            # Skip public keys and non-files
            [[ "$f" == *.pub ]] && continue
            [ -f "$f" ] || continue
            AVAILABLE_KEYS+=("$f")
        done

        if [ ${#AVAILABLE_KEYS[@]} -eq 0 ]; then
            echo ">> No SSH private keys found in ~/.ssh/. Git SSH operations may fail."
        elif [ ${#AVAILABLE_KEYS[@]} -eq 1 ]; then
            echo ">> Found SSH key: ${AVAILABLE_KEYS[0]}"
            read -rp ">> Add it to the agent? [Y/n] " REPLY
            if [[ -z "$REPLY" || "$REPLY" =~ ^[Yy] ]]; then
                ssh-add "${AVAILABLE_KEYS[0]}"
                echo ">> Key added."
            else
                echo ">> Skipped. You can add it later with: ssh-add ${AVAILABLE_KEYS[0]}"
            fi
        else
            echo ">> Found ${#AVAILABLE_KEYS[@]} SSH keys:"
            for i in "${!AVAILABLE_KEYS[@]}"; do
                echo "   $((i+1))) ${AVAILABLE_KEYS[$i]}"
            done
            read -rp ">> Select a key to add (1-${#AVAILABLE_KEYS[@]}), or 'a' for all, 's' to skip: " CHOICE
            if [[ "$CHOICE" == "a" ]]; then
                for k in "${AVAILABLE_KEYS[@]}"; do
                    ssh-add "$k"
                done
                echo ">> All keys added."
            elif [[ "$CHOICE" == "s" || -z "$CHOICE" ]]; then
                echo ">> Skipped. Add keys manually with: ssh-add <key-path>"
            elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#AVAILABLE_KEYS[@]} ]; then
                ssh-add "${AVAILABLE_KEYS[$((CHOICE-1))]}"
                echo ">> Key added."
            else
                echo ">> Invalid choice. Skipping."
            fi
        fi
    else
        echo ">> Host SSH Agent detected with $KEY_COUNT key(s)."
    fi
fi

echo ">> Starting Claude Code in Prison (isolated container)..."

# Aggressively remove any leftover dead/orphaned container from previous crashes
docker rm -f "claude-prison-session" >/dev/null 2>&1 || true

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

# Ensure Homebrew path is available in case the wrapper is invoked in a clean environment
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Run the container (with tmux integration for claude-gym)
if command -v tmux >/dev/null 2>&1; then
    CGYM_BIN="$SCRIPT_DIR/claude-gym/cgym"
    if [ ! -f "$CGYM_BIN" ]; then
        echo ">> Building claude-gym natively for tmux integration..."
        (cd "$SCRIPT_DIR/claude-gym" && go build -o cgym .) || true
    fi

    if [ -f "$CGYM_BIN" ]; then
        if [ -n "$TMUX" ]; then
            echo ">> Splitting current tmux window for Claude Gym..."
            # Explicitly target the current window and pane when splitting
            tmux split-window -h -t "{active}" -p 30 "CLAUDE_BASE_DIR=\"$CLAUDE_CONFIG_DIR\" CLAUDE_PROJECT_PATH=\"$CLAUDE_CONFIG_DIR/projects/-workspace\" $CGYM_BIN"
            exec "${DOCKER_CMD[@]}" "$IMAGE_NAME" claude --dangerously-skip-permissions "$@"
        else
            echo ">> Starting Claude Prison with Claude Gym in a new tmux session..."
            SESSION_NAME="claude-prison-$$"
            
            # Start a detached tmux session running a persistent shell
            tmux new-session -d -s "$SESSION_NAME" "bash"
            
            # Formulate the exact command string and send it to the shell
            CMD_STRING="${DOCKER_CMD[*]} $IMAGE_NAME claude --dangerously-skip-permissions $*"
            tmux send-keys -t "$SESSION_NAME" "$CMD_STRING" C-m
            
            # Split the window (right pane 30% width) for claude-gym, passing the configuration directory and Docker path
            tmux split-window -h -t "$SESSION_NAME" -p 30 "CLAUDE_BASE_DIR=\"$CLAUDE_CONFIG_DIR\" CLAUDE_PROJECT_PATH=\"$CLAUDE_CONFIG_DIR/projects/-workspace\" $CGYM_BIN"
            
            # Select the left pane (Claude) so user input focuses there
            tmux select-pane -t "$SESSION_NAME":0.0
            
            # Attach and replace current shell
            exec tmux attach-session -t "$SESSION_NAME"
        fi
    fi
fi

# Fallback: run normally if tmux isn't available or gym failed to build
exec "${DOCKER_CMD[@]}" "$IMAGE_NAME" claude --dangerously-skip-permissions "$@"
