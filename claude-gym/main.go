package main

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

// getAssetPath returns the path to an asset file, searching relative to the binary location
func getAssetPath(relativePath string) string {
	if exe, err := os.Executable(); err == nil {
		exeDir := filepath.Dir(exe)
		if resolved, err := filepath.EvalSymlinks(exe); err == nil {
			exeDir = filepath.Dir(resolved)
		}
		candidate := filepath.Join(exeDir, "assets", relativePath)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}
	return filepath.Join("assets", relativePath)
}

func printUsage() {
	fmt.Println(`Claude Gym - Exercise Reminder for Claude Code Users (TUI Edition)

Usage:
  cgym                    Watch the current directory's latest conversation
  cgym watch [dir]        Watch a specific directory's conversation
  cgym replay <file>      Replay an existing conversation JSONL file

Options:
  -s, --speed <ms>      Replay speed in milliseconds (default: 200)
  -h, --help            Show this help message`)
}

func main() {
	watcher := NewWatcher()
	var err error

	args := os.Args[1:]

	if len(args) == 0 {
		cwd, _ := os.Getwd()
		err = watcher.FindProjectConversation(cwd)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		err = watcher.StartLive()
	} else {
		switch args[0] {
		case "-h", "--help", "help":
			printUsage()
			os.Exit(0)

		case "watch":
			dir := "."
			if len(args) > 1 {
				dir = args[1]
			}
			err = watcher.FindProjectConversation(dir)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				os.Exit(1)
			}
			err = watcher.StartLive()

		case "replay":
			if len(args) < 2 {
				fmt.Fprintln(os.Stderr, "Error: replay requires a file path")
				printUsage()
				os.Exit(1)
			}
			filePath := args[1]

			for i := 2; i < len(args); i++ {
				if args[i] == "-s" || args[i] == "--speed" {
					if i+1 < len(args) {
						var speed int
						fmt.Sscanf(args[i+1], "%d", &speed)
						if speed > 0 {
							watcher.ReplaySpeed = time.Duration(speed) * time.Millisecond
						}
					}
				}
			}

			err = watcher.StartReplay(filePath)

		default:
			err = watcher.FindProjectConversation(args[0])
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				os.Exit(1)
			}
			err = watcher.StartLive()
		}
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	// Load exercises
	exercisePath := getAssetPath("../exercises.json")
	exercises, exErr := LoadExercises(exercisePath)
	if exErr != nil {
		exercises, exErr = LoadExercises("exercises.json")
		if exErr != nil {
			fmt.Fprintf(os.Stderr, "Warning: %v (using defaults)\n", exErr)
			exercises = []ExerciseConfig{
				{Name: "Chair Dips", AnimRow: 3, Reps: "10 reps"},
				{Name: "Arm Circles", AnimRow: 4, Reps: "20 forward + 20 backward"},
			}
		}
	}

	exerciseLog := LoadExerciseLog()

	appState := &AppModel{
		watcher:   watcher,
		exercises: exercises,
		log:       exerciseLog,
		state:     UIIdle,
		lastEvent: time.Now(),
	}
	appState.setAnimation("coffee_idle")

	p := tea.NewProgram(appState, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error starting TUI: %v\n", err)
		os.Exit(1)
	}
}
