package system

import (
	"context"
	"fmt"
	"sort"
	"strings"
)

// Command is the only supported boundary for invoking host commands.
// SensitiveValues are removed from display strings, captured output and errors.
type Command struct {
	Name            string
	Args            []string
	Env             map[string]string
	Step            string
	SensitiveValues []string
}

func (c Command) String() string {
	parts := make([]string, 0, len(c.Args)+1)
	parts = append(parts, c.Name)
	parts = append(parts, c.Args...)
	return redact(strings.Join(parts, " "), c.SensitiveValues)
}

func (c Command) Environment() []string {
	keys := make([]string, 0, len(c.Env))
	for key := range c.Env {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	out := make([]string, 0, len(keys))
	for _, key := range keys {
		out = append(out, key+"="+c.Env[key])
	}
	return out
}

type Result struct {
	Stdout   string
	Stderr   string
	ExitCode int
}

type Runner interface {
	Run(ctx context.Context, command Command) (Result, error)
}

type CommandError struct {
	Command Command
	Result  Result
	Cause   error
}

func (e *CommandError) Error() string {
	step := strings.TrimSpace(e.Command.Step)
	if step == "" {
		step = "run command"
	}
	detail := strings.TrimSpace(e.Result.Stderr)
	if detail == "" && e.Cause != nil {
		detail = e.Cause.Error()
	}
	detail = redact(detail, e.Command.SensitiveValues)
	if detail == "" {
		return fmt.Sprintf("%s failed: %s (exit %d)", step, e.Command.String(), e.Result.ExitCode)
	}
	return fmt.Sprintf("%s failed: %s (exit %d): %s", step, e.Command.String(), e.Result.ExitCode, detail)
}

func (e *CommandError) Unwrap() error { return e.Cause }

func redact(value string, secrets []string) string {
	for _, secret := range secrets {
		if secret == "" {
			continue
		}
		value = strings.ReplaceAll(value, secret, "[REDACTED]")
	}
	return value
}
