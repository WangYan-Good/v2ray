package system

import (
	"context"
	"errors"
	"strings"
	"testing"
)

func TestRecordingRunnerOrderAndFailure(t *testing.T) {
	runner := &RecordingRunner{Failures: map[int]error{1: errors.New("boom")}}
	if _, err := runner.Run(context.Background(), Command{Name: "nginx", Args: []string{"-t"}}); err != nil {
		t.Fatal(err)
	}
	_, err := runner.Run(context.Background(), Command{Name: "systemctl", Args: []string{"reload", "nginx"}, Step: "reload nginx"})
	if err == nil || !strings.Contains(err.Error(), "reload nginx failed") {
		t.Fatalf("error = %v", err)
	}
	want := []string{"nginx -t", "systemctl reload nginx"}
	got := runner.Strings()
	if strings.Join(got, "\n") != strings.Join(want, "\n") {
		t.Fatalf("commands = %v", got)
	}
}

func TestCommandErrorRedactsSecrets(t *testing.T) {
	secret := "11111111-1111-4111-8111-111111111111"
	command := Command{Name: "xray", Args: []string{"test", secret}, SensitiveValues: []string{secret}}
	err := (&CommandError{Command: command, Result: Result{Stderr: "invalid " + secret, ExitCode: 23}}).Error()
	if strings.Contains(err, secret) || !strings.Contains(err, "[REDACTED]") {
		t.Fatalf("error was not redacted: %s", err)
	}
}
