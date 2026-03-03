# Contributing to Claude Gym

Thanks for your interest in contributing! Here's how to get started.

## Dev Environment Setup

**Requirements:**
- Go 1.25+

**Clone and build:**

```bash
git clone https://github.com/477-Studio/claude-gym.git
cd claude-gym
go build -o cgym .
```

**Run:**

```bash
./cgym                          # Watch current project
./cgym watch ~/path/to/project  # Watch specific project
./cgym replay <file.jsonl>      # Replay a conversation
```

## Adding a New Exercise

1. Create 16 animation frames in `cmd/devsprite/generate_exercises.py` for the new exercise
2. Run `python3 cmd/devsprite/generate_exercises.py` to generate the `.ansi` frame files
3. Add an entry to `exercises.json`:
   ```json
   {"name": "Your Exercise", "anim_row": <row_number>, "reps": "10 reps"}
   ```
4. Add the animation name mapping in `exercises.go` (`AnimName()` method)

## Project Structure

See [CLAUDE.md](CLAUDE.md) for full architecture details. Key files:

- `main.go` — entry point, CLI parsing
- `tui.go` — Bubbletea TUI, state machine, rendering
- `exercises.go` — exercise config loader
- `exercise_log.go` — persistent exercise history
- `watcher.go` — JSONL file watcher and event parser
- `exercises.json` — exercise definitions

## PR Process

1. Fork the repo.
2. Create a feature branch.
3. Make your changes and verify with `go build`.
4. Open a PR against `main`.
