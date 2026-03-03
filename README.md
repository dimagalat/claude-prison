# Claude Prison

Claude Prison is a specialized wrapper and Docker environment designed to securely run Anthropic's [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) CLI using the `--dangerously-skip-permissions` flag. 

By running Claude Code inside a Docker container, it can safely plan, create, and execute shell commands autonomously without affecting your host machine or risking accidental data loss.

## Features
- **Total Host Isolation:** Claude cannot edit files or run destructive commands outside of the mounted `/workspace`.
- **Git Identity:** Your `~/.gitconfig` is mounted strictly `read-only` so Claude commits code as you.
- **Secure SSH Commits:** Rather than directly exposing your private `~/.ssh` keys, the wrapper forwards your `SSH_AUTH_SOCK`, allowing Claude to push commits to GitHub securely.
- **Persistent Sessions:** Claude Code's login credentials and settings are persisted locally in `~/.config/claude-prison`.
- **Correct Privileges:** The `entrypoint.sh` logic dynamically maps your host machine's User ID (UID/GID) inside the container. This means any Python files, Node modules, or directories Claude makes are owned by *you*, not Docker's `root` user.
- **Bundled Tools:** The image includes `git`, `python3`, `node`, `curl`, `build-base`, and the `docker` CLI.
- **Claude Gym Integration:** Automatically spins up a side-by-side [Claude Gym](https://github.com/477-Studio/claude-gym) instance in a split `tmux` pane to remind you to stretch while Claude writes code.

## Prerequisites
- **Docker** installed and running on your host machine.
- An **Anthropic Console** account with billing set up (required for the underlying `claude` CLI).

## Setup & Authentication (Critical Step)
Before Claude Code can work, it needs to be authenticated with your Anthropic account. This process uses an OAuth flow that will open a browser to generate a token. **This token is securely preserved in `~/.config/claude-prison` so you only have to do this once.**

1. Clone this repository anywhere on your machine:
   ```bash
   git clone https://github.com/your-username/claude-prison.git ~/.claude-prison
   cd ~/.claude-prison
   ```
2. Ensure you have an active SSH Agent running (if you want Claude to `git push`):
   ```bash
   eval $(ssh-agent)
   ssh-add ~/.ssh/id_ed25519 # Or whatever your key name is
   ```
3. Run the initial login sequence:
   ```bash
   make run
   ```
   *The very first time you execute this, Docker will build the Alpine container and install Claude Code. Because Claude Code doesn't detect credentials in the mounted config volume, it will immediately prompt you with an OAuth link and code.*
4. Follow the CLI prompt: Open your browser, paste the authorization code provided in the terminal, and approve the connection in the Anthropic Console.
5. Once the terminal reports "Authentication Successful", you are inside the interactive restricted prison shell! You can type `/exit` to leave.

## Global Installation (Highly Recommended)
Once you have authenticated, you probably want to be able to run `clp` inside any project folder on your machine without copying files around.

You can install `clp` globally by running:
```bash
make install
```

By default, this symlinks the `clp` wrapper script into `~/.local/bin` (make sure this is in your `$PATH`), allowing you to walk into any project directory and instantly summon the Dockerized Claude.

If you don't use `~/.local/bin` and want to install it somewhere else (like `/usr/local/bin`), you can configure the installation directory like so:
```bash
make install BIN_DIR=/usr/local/bin
```

*Note: If your terminal says `command not found: clp` after installation, run `make config` for instructions on how to add `~/.local/bin` or your custom installation directory to your system's `$PATH`.*

## Usage

To use Claude Prison for a project:

1. Navigate to your project directory.
2. Execute the wrapper:
   ```bash
   clp
   ```
3. You are now in a sandboxed, interactive Claude Code session. The `--dangerously-skip-permissions` flag is active, meaning you can assign comprehensive tasks like:
   - *"Build me a Python web scraper, install requests, and test it."*
   - *"Write a new Dockerfile and build it to test."*
   - *"Refactor the entire login component and run the unit tests."*
   - *"Commit everything to a new branch and push."*

Because it is contained, Claude will seamlessly execute `npm install`, `mkdir`, `python3`, `git commit` and `docker build` without constantly pinging you for `Y/N` permission approvals!

### Claude Gym Side-by-Side

This repository includes a customized version of [Claude Gym](https://github.com/477-Studio/claude-gym) featuring a developer in an orange prison jumpsuit.

When you execute `clp`, the script checks if `tmux` is installed. If so, it:
1. Orchestrates a `tmux` session on your macOS host.
2. Splits your terminal into two panes.
3. Runs the isolated `claude-prison` Docker shell on the left.
4. Runs `claude-gym` natively on the right (at 30% width) to monitor the ongoing conversation logs and prompt you to exercise!
