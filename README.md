# Claude Prison

Claude Prison is a specialized wrapper and Docker environment designed to securely run Anthropic's [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) CLI using the `--dangerously-skip-permissions` flag. 

By running Claude Code inside a Docker container, it can safely plan, create, and execute shell commands autonomously without affecting your host machine or risking accidental data loss.

## Features
- **Total Host Isolation:** Claude cannot edit files or run destructive commands outside of the mounted `/workspace`.
- **Git Identity:** Your `~/.gitconfig` is mounted strictly `read-only` so Claude commits code as you.
- **Secure SSH Commits:** Rather than directly exposing your private `~/.ssh` keys, the wrapper forwards your `SSH_AUTH_SOCK`, allowing Claude to push commits to GitHub securely (NEEDS WORK)
- **Persistent Sessions:** Claude Code's login credentials and settings are persisted locally in `~/.config/claude-prison`. (you will need to run claude on a host machine once a day to refresh the Claude credentials)

### Also
- **Correct Privileges:** The `entrypoint.sh` logic dynamically maps your host machine's User ID (UID/GID) inside the container. This means any Python files, Node modules, or directories Claude makes are owned by *you*, not Docker's `root` user.
- **Bundled Tools:** The image includes `git`, `node`, `curl`, `bash`, `openssh-client`, and the `docker` CLI.
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
   ssh-add ~/.ssh/{something} # Or whatever your key name is
   ```
3. Run the initial login sequence:
   ```bash
   make build
   ```
   *The very first time you execute this, Docker will build the Alpine container and install Claude Code*
4. Update your claude config ```claude``` and authorise via the browser. Once the terminal reports "Authentication Successful", you are you are ready to run ```./clp```.

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

## Skills Support
Claude Code natively loads external capabilities from your `~/.claude/skills` directory, and `clp` automatically exposes these skills to your container by passing your config folder.

However, if those skills require underlying system packages (like Playwright, ffmpeg) or Python pip packages, you can ask Docker to install them directly into the environment image by running:
```bash
make build-with-skills
```
*Note: This will check your host's `~/.claude/skills` directory and install dependencies if they have an `install-skills.sh` file or valid `dependencies.json` configurations.*

You can also target specific skills rather than all of them:
```bash
make build-with-skills SKILLS="webapp-testing some-other-skill"
```

## Usage

To use Claude Prison for a project:

1. Navigate to your project directory.
2. Execute the wrapper:
   ```bash
   clp
   ```
3. You are now in a sandboxed, interactive Claude Code session. The `--dangerously-skip-permissions` flag is active.
Because it is contained, Claude will seamlessly execute commands without constantly pinging you for permission approvals!

### Claude Gym Side-by-Side

This repository includes a customized version of [Claude Gym](https://github.com/477-Studio/claude-gym) featuring a developer in an orange prison jumpsuit.

When you execute `clp`, the script checks if `tmux` is installed. If so, it:
1. Orchestrates a `tmux` session on your macOS host.
2. Splits your terminal into two panes.
3. Runs the isolated `claude-prison` Docker shell on the left.
4. Runs `claude-gym` natively on the right (at 30% width) to monitor the ongoing conversation logs and prompt you to exercise!
