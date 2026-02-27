#!/bin/bash
# clp-install - Installs Claude Prison helper script globally

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${1:-${BIN_DIR:-$HOME/.local/bin}}"

echo ">> Installing Claude Prison to $BIN_DIR..."

# We don't copy the Dockerfile and entrypoint.sh everywhere. 
# We just symlink the 'clp' script to /usr/local/bin so it can be executed from anywhere.
# The 'clp' script already intelligently resolves its SCRIPT_DIR to find the Dockerfile.

# Create ~/.local/bin if it doesn't already exist
mkdir -p "$BIN_DIR"

ln -sf "$SCRIPT_DIR/clp" "$BIN_DIR/clp"

# Ensure clp is executable
chmod +x "$SCRIPT_DIR/clp"

echo ">> Successfully installed 'clp' to $BIN_DIR/clp"
echo ">> You can now run 'clp' in any directory to open an isolated Claude session."
