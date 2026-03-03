package main

import (
	"encoding/json"
	"fmt"
	"os"
)

// ExerciseConfig defines a single exercise type
type ExerciseConfig struct {
	Name    string `json:"name"`
	AnimRow int    `json:"anim_row"`
	Reps    string `json:"reps"`
}

// AnimName returns the string identifier for the animation files based on anim_row
func (e ExerciseConfig) AnimName() string {
	mapping := map[int]string{
		3:  "chair_dips",
		4:  "arm_circles",
		6:  "knee_raises",
		7:  "spinal_twist",
		8:  "glute_squeeze",
		9:  "shoulder_rolls",
		10: "leg_extensions",
		11: "neck_stretch",
		12: "desk_pushups",
		13: "squats",
		14: "calf_raises",
		15: "wall_sit",
		16: "torso_rotation",
		17: "reverse_lunges",
	}
	if name, ok := mapping[e.AnimRow]; ok {
		return name
	}
	// Fallback to pushups if unknown
	return "desk_pushups"
}

// BubbleText returns the speech bubble text for this exercise
func (e ExerciseConfig) BubbleText() string {
	return fmt.Sprintf("Let's do %s!\n%s", e.Name, e.Reps)
}

// CompletedExercise tracks a single completed exercise
type CompletedExercise struct {
	Name     string
	Reps     string
	Duration float32 // seconds spent on this exercise
}

// LoadExercises reads exercise configs from a JSON file
func LoadExercises(path string) ([]ExerciseConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read exercises file: %w", err)
	}

	var exercises []ExerciseConfig
	if err := json.Unmarshal(data, &exercises); err != nil {
		return nil, fmt.Errorf("failed to parse exercises: %w", err)
	}

	if len(exercises) == 0 {
		return nil, fmt.Errorf("no exercises found in %s", path)
	}

	return exercises, nil
}
