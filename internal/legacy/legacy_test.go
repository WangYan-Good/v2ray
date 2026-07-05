package legacy

import (
	"bytes"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type fakeRunner struct {
	code int
	args []string
	path string
}

func (f *fakeRunner) Run(path string, args []string, stdin io.Reader, stdout, stderr io.Writer) (int, error) {
	f.path = path
	f.args = append([]string{}, args...)
	_, _ = stdout.Write([]byte("legacy stdout\n"))
	return f.code, nil
}

func TestClassifyCommands(t *testing.T) {
	if Classify("version") != "migrated" {
		t.Fatal("version should be migrated")
	}
	if Classify("add") != "legacy" {
		t.Fatal("add should be legacy")
	}
	if Classify("missing-command") != "unknown" {
		t.Fatal("missing-command should be unknown")
	}
}

func TestDelegatePassesArgsAndExitCode(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "xray.sh")
	if err := os.WriteFile(path, []byte("#!/usr/bin/env bash\n"), 0o755); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	runner := &fakeRunner{code: 7}
	code := Delegate(path, []string{"add", "vws"}, nil, &stdout, &stderr, runner)
	if code != 7 {
		t.Fatalf("code = %d", code)
	}
	if runner.path != path || strings.Join(runner.args, " ") != "add vws" {
		t.Fatalf("runner path/args = %s %v", runner.path, runner.args)
	}
	if !strings.Contains(stderr.String(), `delegating legacy command "add"`) {
		t.Fatalf("stderr = %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "legacy stdout") {
		t.Fatalf("stdout = %s", stdout.String())
	}
}

func TestValidatePathRejectsRecursiveEntry(t *testing.T) {
	if err := ValidatePath("/usr/local/bin/xray"); err == nil {
		t.Fatal("expected recursive path error")
	}
}

func TestSwitchPlan(t *testing.T) {
	out := FormatSwitchPlan(NewSwitchPlan(""))
	for _, want := range []string{
		"mode = go",
		"entry = /usr/local/bin/xray",
		"legacy = /etc/xray/sh/xray.sh",
		"rollback = ln -sf /etc/xray/sh/xray.sh /usr/local/bin/xray",
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("switch plan missing %q:\n%s", want, out)
		}
	}
}
