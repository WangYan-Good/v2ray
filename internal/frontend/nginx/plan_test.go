package nginx

import (
	"strings"
	"testing"

	"github.com/WangYan-Good/xray/internal/acme"
)

func TestCertbotIssueUsesConfiguredEmail(t *testing.T) {
	command := CertbotIssueCommand("example.com", acme.Config{Email: "user@example.com"})
	joined := command.String()
	for _, want := range []string{"certonly --webroot", "--non-interactive", "--agree-tos", "--keep-until-expiring", "--email user@example.com"} {
		if !strings.Contains(joined, want) {
			t.Fatalf("command missing %q: %s", want, joined)
		}
	}
	if strings.Contains(joined, "standalone") {
		t.Fatalf("command uses standalone: %s", joined)
	}
}

func TestCertbotIssueRequiresExplicitNoEmail(t *testing.T) {
	command := CertbotIssueCommand("example.com", acme.Config{NoEmail: true})
	if !strings.Contains(command.String(), "--register-unsafely-without-email") {
		t.Fatalf("command = %s", command.String())
	}
}

func TestDeployHook(t *testing.T) {
	if !strings.Contains(DeployHook, "nginx -t\nsystemctl reload nginx") {
		t.Fatalf("hook = %s", DeployHook)
	}
	if strings.Contains(CertbotRenewDryRunCommand().String(), "deploy-hook") {
		t.Fatalf("dry-run command must use persistent hook")
	}
}

func TestRenewalTimerFromUnitFiles(t *testing.T) {
	for _, test := range []struct {
		output string
		want   string
	}{
		{"certbot.timer enabled enabled\n", "certbot.timer"},
		{"certbot-renew.timer enabled enabled\n", "certbot-renew.timer"},
		{"", ""},
	} {
		if got := RenewalTimerFromUnitFiles(test.output); got != test.want {
			t.Fatalf("RenewalTimerFromUnitFiles(%q) = %q, want %q", test.output, got, test.want)
		}
	}
}
