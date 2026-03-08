#!/bin/bash
# Install dependencies for selected skills.
#
# Usage:
#   install-skills.sh                     # install all skills in /skills/
#   install-skills.sh webapp-testing      # install specific skill(s)
#
# Each skill directory may contain a dependencies.json with the following fields:
#
#   {
#     "apk":          ["pkg1", "pkg2"],      # Alpine packages to install
#     "pip":          ["pkg1", "pkg2"],      # Python packages to install via pip
#     "post_install": ["cmd1", "cmd2"],      # Shell commands to run after installation
#     "env":          {"KEY": "value"}       # Environment variables for runtime
#   }
#
# All fields are optional. Packages are deduplicated across skills before
# installing. Environment variables are written to /skills/env.sh, which
# the container entrypoint sources at startup.

set -e

SKILLS_DIR="/skills"

if [ $# -gt 0 ]; then
    skills=("$@")
else
    skills=()
    for dir in "$SKILLS_DIR"/*/; do
        [ -d "$dir" ] && skills+=("$(basename "$dir")")
    done
fi

if [ ${#skills[@]} -eq 0 ]; then
    echo ">> No skills to install."
    exit 0
fi

all_apk=()
all_pip=()
all_post=()

for skill in "${skills[@]}"; do
    deps="$SKILLS_DIR/$skill/dependencies.json"
    if [ ! -f "$deps" ]; then
        echo ">> Skill '$skill': no dependencies.json, skipping dependency install"
        continue
    fi

    echo ">> Skill '$skill': reading dependencies..."

    # Collect apk packages
    while IFS= read -r pkg; do
        [ -n "$pkg" ] && all_apk+=("$pkg")
    done < <(python3 -c "import json,sys; d=json.load(open('$deps')); [print(p) for p in d.get('apk',[])]" 2>/dev/null || true)

    # Collect pip packages
    while IFS= read -r pkg; do
        [ -n "$pkg" ] && all_pip+=("$pkg")
    done < <(python3 -c "import json,sys; d=json.load(open('$deps')); [print(p) for p in d.get('pip',[])]" 2>/dev/null || true)

    # Collect post-install commands
    while IFS= read -r cmd; do
        [ -n "$cmd" ] && all_post+=("$cmd")
    done < <(python3 -c "import json,sys; d=json.load(open('$deps')); [print(c) for c in d.get('post_install',[])]" 2>/dev/null || true)

    # Collect env vars into a shared env file sourced by entrypoint
    python3 -c "
import json, sys, shlex
try:
    d = json.load(open('$deps'))
    for k, v in d.get('env', {}).items():
        print(f'export {k}={shlex.quote(str(v))}')
except Exception:
    pass
" 2>/dev/null >> "$SKILLS_DIR/env.sh" || true
done

# Install apk packages (deduplicated)
if [ ${#all_apk[@]} -gt 0 ]; then
    unique_apk=($(printf '%s\n' "${all_apk[@]}" | sort -u))
    echo ">> Installing apt packages: ${unique_apk[*]}"
    apt-get update && apt-get install -y --no-install-recommends "${unique_apk[@]}" && rm -rf /var/lib/apt/lists/*
fi

if [ ${#all_pip[@]} -gt 0 ]; then
    unique_pip=($(printf '%s\n' "${all_pip[@]}" | sort -u))
    echo ">> Installing pip packages: ${unique_pip[*]}"
    pip3 install --no-cache-dir --break-system-packages "${unique_pip[@]}"
fi

# Run post-install commands
for cmd in "${all_post[@]}"; do
    echo ">> Running: $cmd"
    eval "$cmd"
done

echo ">> Skills installation complete."
