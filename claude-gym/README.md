# Claude Gym (TUI Edition)

<p align="center">
  <strong>A terminal-based exercise companion that nudges you to move during long Claude Code runs</strong>
</p>

This is a **Terminal UI (TUI) fork** of the original [Claude Gym by 477-Studio](https://github.com/477-Studio/claude-gym). The original application runs using the hardware-accelerated Raylib OpenGL engine, which pops out as a native MacOS desktop window.

To allow Claude Gym to seamlessly run **inside a split tmux pane** directly within your terminal next to `claude-prison`, the entire graphical rendering pipeline was ripped out and replaced with [Bubbletea](https://github.com/charmbracelet/bubbletea)!

The 32x32 pixel sprites have been converted into identical `ANSI` half-block text characters, allowing them to animate at 60 FPS natively in your console. 

### Integrated Office Scene
The TUI edition restores the original's home office environment using procedural ASCII generation:
- **Padded 64x48 Viewport:** The scene and animations have been expanded into a cozy office view.
- **Furniture Props:** High-fidelity pixel-art representations of the desk, office chair, monitor, and window are baked into the ANSI frames.
- **Layering:** Smart z-index awareness means Luca correctly leans *behind* the desk during specific exercises like desk push-ups.
- **Proportion Accuracy:** We utilize Unicode half-blocks (`▄`) to maintain a perfect 1:1 pixel aspect ratio, ensuring no "stretching" in modern terminal emulators.

## How It Works

It reads Claude Code's local JSONL logs. No API keys. No network. No telemetry. Just file watching.

- CC enters **plan mode** or **spawns a subagent** → Luca waves, "time to exercise!"
- CC goes on a **3+ tool call streak** → same thing, you're not needed anyway
- CC **needs you back** → prompt auto-dismisses, zero friction

More than ten exercises with retro terminal character animations — squats, desk push-ups, wall sits, arm circles, and more.

## Usage with Claude Prison

This application is strictly bundled with `claude-prison`. To run it, simply execute the wrapper script from your project root:

```bash
./clp
```

The script will automatically compile this TUI engine, allocate a background `tmux` session, mount the correct configuration directories, and split your current window into two panes: the left side for `claude` (in Docker) and the right side for `claude-gym` (native TUI).

## Manual Usage

```bash
# Watch the current directory's conversation
cgym

# Watch a specific directory
cgym watch [dir]

# Replay an existing conversation JSONL file (useful for testing)
cgym replay <file>
```

## Attribution

All pixel art assets, exercise scheduling logic, log parsing mechanics, and the original architecture belong to the creators of the graphical [Claude Gym](https://github.com/477-Studio/claude-gym). This fork maintains their structural integrity while swapping out the rendering engine for Terminal UX.
