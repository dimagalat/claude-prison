# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
go build -o cgym .              # Build binary for current platform
./cgym                          # Watch the current directory's latest conversation
./cgym watch ~/path/to/project  # Watch a specific directory's conversation
./cgym replay <jsonl-file>      # Replay a conversation file
```

## Architecture

Claude Gym is a TUI exercise reminder companion for Claude Code users. It watches JSONL conversation logs and prompts the user to do exercises during natural pause points. It renders a pixel-art developer character using ANSI half-block characters in the terminal via [Bubbletea](https://github.com/charmbracelet/bubbletea).

### Core Components

**main.go** - Entry point. Initializes the Bubbletea `Program` and passes the initial `AppModel`. Handles CLI arguments for `watch` and `replay`.

**tui.go** - The heart of the application. Contains the `AppModel` struct and Bubbletea methods:
- `Init()`: Starts the tick loop and watcher event listener.
- `Update()`: Manages state transitions (Idle, Countdown, Exercising) and handles incoming `Watcher` events.
- `View()`: Renders the final terminal frame, compositing the ANSI sprite and the speech bubble using `lipgloss`.

**watcher.go** - Monitors Claude Code JSONL logs. Emits `Event` structs on a channel when Claude enters thinking mode, runs tools, or finishes a turn. Supports live tailing and replay modes.

**exercises.go** - Loads exercise metadata from `exercises.json`. Maps animation row indices to animation directory names.

**exercise_log.go** - Persistent exercise history tracking. Stores completed exercises with timestamps, supports daily trends and per-type breakdowns.

### Asset Pipeline

**cmd/devsprite/** - Python scripts that generate the animation assets:
- `generate.py` - Base developer character (32x32)
- `generate_exercises.py` - Composites character onto 64x48 office scene and exports `.ansi` frames
- `generate_frames.py` - Frame generation utility

### Sprite & Rendering Details

- **Grid Size:** 64 columns x 48 rows (logical pixels).
- **ANSI Output:** 64 columns x 24 rows (physical characters), using Unicode half-blocks (`▄`) to represent two vertical pixels per character cell.
- **Color:** 24-bit TrueColor (RGB) escape sequences.
- Each animation has 16 frames stored as individual `.ansi` files in `assets/developer/`.

### Event Flow

1. Watcher parses JSONL and emits `Event{Type, Details, ...}`
2. `AppModel.Update()` checks for events that should trigger exercise prompts
3. If triggered, character waves and prompts "Time to exercise!"
4. Countdown → Exercise animation plays for duration → Returns to idle

## Local Development

When modifying animations or the background scene:
1. Edit the `create_office_bg` function in `cmd/devsprite/generate_exercises.py`.
2. Run `python3 cmd/devsprite/generate_exercises.py` to bake new `.ansi` frames.
3. Restart `cgym` to see changes.

## Important Notes

- **Proportions:** The TUI uses a 1:1 pixel aspect ratio by stacking two pixels per character cell. Do not change the half-block logic in `generate_exercises.py` without testing across different terminal emulators.
- **Tmux:** `cgym` is designed to be run in a 30%-width side pane via the `clp` wrapper script.
- **Pure Go:** No CGO required. All dependencies (bubbletea, lipgloss) are pure Go.
