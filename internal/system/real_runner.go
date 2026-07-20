package system

import (
	"bytes"
	"context"
	"errors"
	"io"
	"os"
	"os/exec"
)

type RealRunner struct {
	Stdin  io.Reader
	Stdout io.Writer
	Stderr io.Writer
}

func (r *RealRunner) Run(ctx context.Context, command Command) (Result, error) {
	cmd := exec.CommandContext(ctx, command.Name, command.Args...)
	cmd.Stdin = r.Stdin
	cmd.Env = append(os.Environ(), command.Environment()...)

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	result := Result{
		Stdout:   redact(stdout.String(), command.SensitiveValues),
		Stderr:   redact(stderr.String(), command.SensitiveValues),
		ExitCode: 0,
	}
	if r.Stdout != nil {
		_, _ = io.WriteString(r.Stdout, result.Stdout)
	}
	if r.Stderr != nil {
		_, _ = io.WriteString(r.Stderr, result.Stderr)
	}
	if err == nil {
		return result, nil
	}

	result.ExitCode = -1
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		result.ExitCode = exitErr.ExitCode()
	}
	return result, &CommandError{Command: command, Result: result, Cause: err}
}
