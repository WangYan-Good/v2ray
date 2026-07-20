package system

import (
	"context"
	"fmt"
	"io"
	"sync"
)

// RecordingRunner records command order and can inject deterministic results.
// Results and Failures use zero-based command indexes.
type RecordingRunner struct {
	mu       sync.Mutex
	Commands []Command
	Results  map[int]Result
	Failures map[int]error
	AfterRun func(index int, command Command)
}

func (r *RecordingRunner) Run(_ context.Context, command Command) (Result, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	index := len(r.Commands)
	r.Commands = append(r.Commands, command)
	result := Result{ExitCode: 0}
	if configured, ok := r.Results[index]; ok {
		result = configured
	}
	if failure, ok := r.Failures[index]; ok {
		if result.ExitCode == 0 {
			result.ExitCode = 1
		}
		return result, &CommandError{Command: command, Result: result, Cause: failure}
	}
	if r.AfterRun != nil {
		r.AfterRun(index, command)
	}
	return result, nil
}

func (r *RecordingRunner) Strings() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]string, 0, len(r.Commands))
	for _, command := range r.Commands {
		out = append(out, command.String())
	}
	return out
}

type DryRunner struct {
	Writer io.Writer
}

func (r DryRunner) Run(_ context.Context, command Command) (Result, error) {
	line := fmt.Sprintf("dry_run = %s\n", command.String())
	if r.Writer != nil {
		_, _ = io.WriteString(r.Writer, line)
	}
	return Result{Stdout: line, ExitCode: 0}, nil
}
