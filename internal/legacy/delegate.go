package legacy

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
)

type Runner interface {
	Run(path string, args []string, stdin io.Reader, stdout, stderr io.Writer) (int, error)
}

type OSRunner struct{}

func (OSRunner) Run(path string, args []string, stdin io.Reader, stdout, stderr io.Writer) (int, error) {
	cmd := exec.Command(path, args...)
	cmd.Stdin = stdin
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	err := cmd.Run()
	if err == nil {
		return 0, nil
	}

	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return exitErr.ExitCode(), nil
	}
	return 1, err
}

func PathFromEnv(getenv func(string) string) string {
	if getenv == nil {
		getenv = os.Getenv
	}
	if value := getenv("XRAY_LEGACY_BIN"); value != "" {
		return value
	}
	return DefaultPath
}

func ValidatePath(path string) error {
	if path == "" {
		return fmt.Errorf("legacy path is empty")
	}
	if filepath.Clean(path) == "/usr/local/bin/xray" {
		return fmt.Errorf("legacy path must not point to /usr/local/bin/xray")
	}
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("legacy command requires Bash entry %s: %w", path, err)
	}
	if info.IsDir() {
		return fmt.Errorf("legacy command requires file, got directory: %s", path)
	}
	return nil
}

func Delegate(path string, args []string, stdin io.Reader, stdout, stderr io.Writer, runner Runner) int {
	if runner == nil {
		runner = OSRunner{}
	}
	if err := ValidatePath(path); err != nil {
		fmt.Fprintln(stderr, err)
		return 3
	}
	if len(args) == 0 {
		fmt.Fprintln(stderr, "legacy command required")
		return 2
	}
	fmt.Fprintf(stderr, "warning: delegating legacy command %q to %s\n", args[0], path)
	code, err := runner.Run(path, args, stdin, stdout, stderr)
	if err != nil {
		fmt.Fprintf(stderr, "legacy command failed: %v\n", err)
		return 1
	}
	return code
}
