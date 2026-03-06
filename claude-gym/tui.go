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
	frames       []string // raw ANSI frames
	frameIdx     int
	speechBubble string

	// Terminal dimensions for adaptive sizing
	termWidth  int
	termHeight int

	// State tracking
	countdown        int
	exerciseEnd      time.Time
	currentEx        *ExerciseConfig
	lastEvent        time.Time
	lastExercise     time.Time
	exerciseCooldown time.Duration
}

// Init initialize the app with a tick
func (m *AppModel) Init() tea.Cmd {
	return tea.Batch(m.tick(), m.waitForEvent())
}

func (m *AppModel) tick() tea.Cmd {
	return tea.Tick(time.Millisecond*100, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m *AppModel) waitForEvent() tea.Cmd {
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

// countPixels counts ▄ characters in a line (= number of pixel columns).
func countPixels(line string) int {
	return strings.Count(line, "▄")
}

// extendFrame pads the sprite frame with its edge background colors to fill
// targetW columns and targetH lines. The sprite is centered horizontally
// with the left/right edges extended, and the bottom edge extended downward.
func extendFrame(frame string, targetW, targetH int) string {
	lines := strings.Split(frame, "\n")
	// Remove empty trailing lines
	for len(lines) > 0 && strings.TrimSpace(lines[len(lines)-1]) == "" {
		lines = lines[:len(lines)-1]
	}
	if len(lines) == 0 {
		return frame
	}

	srcW := countPixels(lines[0])
	if srcW == 0 {
		return frame
	}

	// Horizontal padding: center the sprite
	padLeft := (targetW - srcW) / 2
	padRight := targetW - srcW - padLeft
	if padLeft < 0 {
		padLeft = 0
	}
	if padRight < 0 {
		padRight = 0
	}

	// If the sprite is taller than targetH, crop from the top
	// (the top is wall/sky; the character is at the bottom).
	if len(lines) > targetH {
		lines = lines[len(lines)-targetH:]
	}

	var result []string
	for _, line := range lines {
		result = append(result, extendLine(line, padLeft, padRight))
	}

	// Extend bottom using the last line's edge colors
	if targetH > len(lines) && len(lines) > 0 {
		lastLine := lines[len(lines)-1]
		leftColor, rightColor := edgeColors(lastLine)
		// Build a solid fill line
		fillLine := solidLine(leftColor, padLeft) +
			solidLine(leftColor, srcW) +
			solidLine(rightColor, padRight) +
			"\033[0m"
		// Use the last line's colors for a uniform bottom fill
		if leftColor == "" {
			leftColor = rightColor
		}
		if leftColor != "" {
			fillLine = solidLine(leftColor, targetW) + "\033[0m"
		}
		for i := len(lines); i < targetH; i++ {
			result = append(result, fillLine)
		}
	}

	return strings.Join(result, "\n")
}

// edgeColors extracts the escape code prefix of the first and last pixel
// in an ANSI half-block line.
func edgeColors(line string) (string, string) {
	parts := strings.Split(line, "▄")
	if len(parts) <= 1 {
		return "", ""
	}
	left := parts[0]
	// Last pixel prefix is parts[len(parts)-2] (parts[-1] is the trailing reset)
	right := left
	if len(parts) >= 2 {
		right = parts[len(parts)-2]
	}
	return left, right
}

// solidLine creates n half-block pixels all with the same ANSI color prefix.
func solidLine(colorPrefix string, n int) string {
	if n <= 0 || colorPrefix == "" {
		return ""
	}
	var sb strings.Builder
	for i := 0; i < n; i++ {
		sb.WriteString(colorPrefix)
		sb.WriteString("▄")
	}
	return sb.String()
}

// extendLine pads a single ANSI line by repeating edge pixel colors.
func extendLine(line string, padLeft, padRight int) string {
	if padLeft == 0 && padRight == 0 {
		return line
	}

	leftColor, rightColor := edgeColors(line)

	var sb strings.Builder
	// Left padding using leftmost pixel color
	sb.WriteString(solidLine(leftColor, padLeft))
	// Original line content (strip trailing reset, we'll add our own)
	core := strings.TrimSuffix(line, "\033[0m")
	sb.WriteString(core)
	// Right padding using rightmost pixel color
	sb.WriteString(solidLine(rightColor, padRight))
	sb.WriteString("\033[0m")
	return sb.String()
}

func (m *AppModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if msg.String() == "q" || msg.String() == "ctrl+c" {
			return m, tea.Quit
		}

	case tea.WindowSizeMsg:
		m.termWidth = msg.Width
		m.termHeight = msg.Height
		return m, nil

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

func (m *AppModel) View() string {
	w := m.termWidth
	h := m.termHeight
	if w <= 0 {
		w = 80
	}
	if h <= 0 {
		h = 24
	}

	// Build speech bubble
	var bubble string
	bubbleLines := 0
	if m.speechBubble != "" {
		maxBubbleW := w - 4
		if maxBubbleW < 10 {
			maxBubbleW = 10
		}
		bubbleStyle := lipgloss.NewStyle().
			MarginLeft(2).
			MaxWidth(maxBubbleW).
			Border(lipgloss.RoundedBorder()).
			Padding(0, 1).
			BorderForeground(lipgloss.Color("63")).
			Foreground(lipgloss.Color("255"))
		bubble = bubbleStyle.Render(m.speechBubble)
		bubbleLines = strings.Count(bubble, "\n") + 1
	}

	// Get frame and extend background to fill terminal
	frame := ""
	if len(m.frames) > 0 && m.frameIdx < len(m.frames) {
		frame = m.frames[m.frameIdx]
	}

	availH := h - bubbleLines - 1
	if availH < 4 {
		availH = 4
	}
	frame = extendFrame(frame, w, availH)

	var sb strings.Builder

	if bubble != "" {
		sb.WriteString(bubble)
		sb.WriteString("\n")
	}

	sb.WriteString(frame)

	return sb.String()
}
