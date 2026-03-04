package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type UIState int

const (
	UIIdle UIState = iota
	UIExercising
	UICountdown
	UIPumpUp
)

type tickMsg time.Time
type eventMsg Event

// AppModel holds the state for the Bubble Tea TUI
type AppModel struct {
	watcher   *Watcher
	exercises []ExerciseConfig
	log       *ExerciseLog

	state        UIState
	currentAnim  string
	frames       []string
	frameIdx     int
	speechBubble string

	// State tracking
	countdown        int
	exerciseEnd      time.Time
	currentEx        *ExerciseConfig
	lastEvent        time.Time
	lastExercise     time.Time
	exerciseCooldown time.Duration
}

// Init initialize the app with a tick
func (m AppModel) Init() tea.Cmd {
	return tea.Batch(m.tick(), m.waitForEvent())
}

func (m AppModel) tick() tea.Cmd {
	return tea.Tick(time.Millisecond*100, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m AppModel) waitForEvent() tea.Cmd {
	return func() tea.Msg {
		return eventMsg(<-m.watcher.Events)
	}
}

func (m *AppModel) setAnimation(animName string) {
	if m.currentAnim == animName && len(m.frames) > 0 {
		return // already playing
	}
	m.currentAnim = animName
	m.frames = m.loadFrames(animName)
	m.frameIdx = 0
}

func (m *AppModel) loadFrames(animName string) []string {
	var frames []string

	// Determine the base path pointing to assets/developer relative to exe
	exePath, err := os.Executable()
	basePath := "assets/developer"
	if err == nil {
		exeDir := filepath.Dir(exePath)
		if resolved, err := filepath.EvalSymlinks(exePath); err == nil {
			exeDir = filepath.Dir(resolved)
		}
		candidate := filepath.Join(exeDir, "assets", "developer")
		if _, err := os.Stat(candidate); err == nil {
			basePath = candidate
		}
	}

	for i := 0; i < 16; i++ {
		path := filepath.Join(basePath, fmt.Sprintf("%s_f%02d.ansi", animName, i))
		data, err := os.ReadFile(path)
		if err != nil {
			// Fallback placeholder if missing
			frames = append(frames, fmt.Sprintf("\n[Missing Frame %d for %s]\n", i, animName))
		} else {
			frames = append(frames, string(data))
		}
	}
	return frames
}

func (m AppModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if msg.String() == "q" || msg.String() == "ctrl+c" {
			return m, tea.Quit
		}

	case tickMsg:
		// Advance frame
		if len(m.frames) > 0 {
			m.frameIdx = (m.frameIdx + 1) % len(m.frames)
		}

		// State machine updates based on time
		now := time.Now()

		switch m.state {
		case UIExercising:
			if now.After(m.exerciseEnd) {
				m.state = UIIdle
				m.setAnimation("coffee_idle")
				m.speechBubble = "Good set!"
			}
		case UIIdle:
			// Clear speech bubble after 5 seconds of idle
			if m.speechBubble != "" && now.Sub(m.lastEvent) > 5*time.Second {
				m.speechBubble = ""
			}
			// If we've been idle for 10 minutes, remind to exercise
			if now.Sub(m.lastEvent) > 10*time.Minute && now.Sub(m.lastExercise) > 15*time.Minute {
				m.triggerExercise()
			}
		case UICountdown:
			remaining := int(m.exerciseEnd.Sub(now).Seconds())
			if remaining <= 0 {
				m.state = UIExercising
				m.setAnimation(m.currentEx.AnimName())
				m.exerciseEnd = now.Add(45 * time.Second) // default exercise duration
				m.lastExercise = now                      // Mark start of exercise
				m.speechBubble = m.currentEx.BubbleText()
			} else {
				m.speechBubble = fmt.Sprintf("Starting in %d...", remaining)
			}
		}

		return m, m.tick()

	case eventMsg:
		ev := Event(msg)
		m.lastEvent = time.Now()

		switch ev.Type {
		case EventSystemInit:
			m.speechBubble = "Watching for Claude..."
		case EventThinking:
			if m.state == UIIdle {
				m.setAnimation("wondering")
				m.speechBubble = "Thinking..."
			}
		case EventBash, EventReading, EventWriting:
			if m.state == UIIdle {
				m.setAnimation("coffee_idle")
				m.speechBubble = "Working on it..."
			}
		case EventSuccess:
			if m.state == UIIdle {
				m.setAnimation("waving")
				m.speechBubble = "Done!"
			}
		case EventError:
			if m.state == UIIdle {
				m.setAnimation("wondering")
				m.speechBubble = "Uh oh, an error!"
			}
		case EventTurnComplete:
			if m.state == UIIdle {
				m.setAnimation("coffee_idle")
				m.speechBubble = "Your turn!"
				// Check if we should exercise (probabilistic after a turn)
				m.checkExerciseTrigger()
			}
		}

		return m, m.waitForEvent()
	}

	return m, nil
}

func (m *AppModel) checkExerciseTrigger() {
	// 1. Probabilistic trigger after a turn (20% chance if 15 mins passed since last exercise)
	if time.Since(m.lastExercise) > 15*time.Minute {
		// Use UnixNano for a simple pseudo-random seed
		if time.Now().UnixNano()%5 == 0 {
			m.triggerExercise()
			return
		}
	}

	// 2. Fallback: Force exercise if it's been over 45 minutes regardless of activity
	if time.Since(m.lastExercise) > 45*time.Minute {
		m.triggerExercise()
	}
}

func (m *AppModel) triggerExercise() {
	if len(m.exercises) == 0 {
		return
	}
	// Pick random exercise
	m.currentEx = &m.exercises[time.Now().UnixNano()%int64(len(m.exercises))]
	m.state = UICountdown
	m.setAnimation("pump_up")
	m.exerciseEnd = time.Now().Add(5 * time.Second) // 5 second countdown
	m.speechBubble = fmt.Sprintf("Time for %s!", m.currentEx.Name)
}

func (m AppModel) View() string {
	frame := ""
	if len(m.frames) > 0 {
		frame = m.frames[m.frameIdx]
	}

	var sb strings.Builder

	// Add padding
	sb.WriteString("\n")

	// Draw speech bubble
	if m.speechBubble != "" {
		bubbleStyle := lipgloss.NewStyle().
			MarginLeft(2).
			Border(lipgloss.RoundedBorder()).
			Padding(0, 1).
			BorderForeground(lipgloss.Color("63")).
			Foreground(lipgloss.Color("255"))
		sb.WriteString(bubbleStyle.Render(m.speechBubble) + "\n")
	} else {
		sb.WriteString("\n\n\n") // Padding where bubble would be
	}

	// Draw sprite
	// The ANSI sprites take up about 16 visual rows
	sb.WriteString(frame)

	sb.WriteString("\n")

	return sb.String()
}
