package nginx

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/WangYan-Good/xray/internal/acme"
	systemexec "github.com/WangYan-Good/xray/internal/system"
)

func TestDeployFreshCertificateOrder(t *testing.T) {
	root := t.TempDir()
	runner := &systemexec.RecordingRunner{Results: map[int]systemexec.Result{
		16: {Stdout: "certbot.timer enabled\n", ExitCode: 0},
	}}
	runner.AfterRun = func(_ int, command systemexec.Command) {
		if !strings.HasPrefix(command.String(), "certbot certonly") {
			return
		}
		writeFixtureFile(t, filepath.Join(root, CertificatePath("example.com")), "certificate")
		writeFixtureFile(t, filepath.Join(root, PrivateKeyPath("example.com")), "private-key")
		writeFixtureFile(t, filepath.Join(root, "etc/letsencrypt/renewal/example.com.conf"), "[renewalparams]\nauthenticator = standalone\ninstaller = nginx\n")
	}
	deployer, err := NewDeployer(DeployOptions{Root: root, Runner: runner, ACME: acme.Config{Email: "user@example.com"}})
	if err != nil {
		t.Fatal(err)
	}
	result, err := deployer.Deploy(context.Background(), profile(t, "vless-ws-tls"))
	if err != nil {
		t.Fatal(err)
	}
	if !result.CertificateIssued || !result.RouteAdded {
		t.Fatalf("result = %+v", result)
	}
	commands := strings.Join(runner.Strings(), "\n")
	issueAt := strings.Index(commands, "certbot certonly --webroot")
	bootstrapReloadAt := strings.Index(commands, "systemctl reload nginx")
	if issueAt < 0 || bootstrapReloadAt < 0 || bootstrapReloadAt > issueAt {
		t.Fatalf("bootstrap did not reload before issue:\n%s", commands)
	}
	if strings.Contains(commands, "standalone") || strings.Contains(commands, "--deploy-hook") {
		t.Fatalf("unsafe Certbot command:\n%s", commands)
	}
	site, err := os.ReadFile(filepath.Join(root, "etc/nginx/xray/example.com.conf"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(site), "/etc/letsencrypt/live/example.com/fullchain.pem") || strings.Contains(string(site), "return 503") {
		t.Fatalf("final site = %s", site)
	}
	hookPath := filepath.Join(root, "etc/letsencrypt/renewal-hooks/deploy/xray-nginx-reload")
	hook, err := os.ReadFile(hookPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(hook) != DeployHook {
		t.Fatalf("hook = %s", hook)
	}
	info, err := os.Stat(hookPath)
	if err != nil || info.Mode().Perm() != 0o755 {
		t.Fatalf("hook mode = %v, error = %v", info.Mode().Perm(), err)
	}
}

func TestDeployRollsBackInvalidFinalConfiguration(t *testing.T) {
	root := t.TempDir()
	sitePath := filepath.Join(root, "etc/nginx/xray/example.com.conf")
	addPath := sitePath + ".add"
	originalSite := `server {
    listen 443 ssl;
    server_name example.com;
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    location /original { proxy_pass http://127.0.0.1:19000; }
	include /etc/nginx/xray/example.com.conf.add;
}
`
	writeFixtureFile(t, sitePath, originalSite)
	writeFixtureFile(t, addPath, "")
	writeFixtureFile(t, filepath.Join(root, CertificatePath("example.com")), "certificate")
	writeFixtureFile(t, filepath.Join(root, PrivateKeyPath("example.com")), "private-key")
	runner := &systemexec.RecordingRunner{Failures: map[int]error{10: errors.New("invalid final config")}}
	deployer, err := NewDeployer(DeployOptions{Root: root, Runner: runner, ACME: acme.Config{Email: "user@example.com"}})
	if err != nil {
		t.Fatal(err)
	}
	next := profile(t, "vless-xhttp-tls")
	next.Path = "/new-route"
	_, err = deployer.Deploy(context.Background(), next)
	if err == nil || !strings.Contains(err.Error(), "invalid final config") {
		t.Fatalf("error = %v", err)
	}
	after, readErr := os.ReadFile(sitePath)
	if readErr != nil {
		t.Fatal(readErr)
	}
	if string(after) != originalSite {
		t.Fatalf("site was not rolled back:\n%s", after)
	}
	add, readErr := os.ReadFile(addPath)
	if readErr != nil || len(add) != 0 {
		t.Fatalf("add was not rolled back: %q, %v", add, readErr)
	}
	commands := runner.Strings()
	if len(commands) < 13 || commands[len(commands)-2] != "nginx -t" || commands[len(commands)-1] != "systemctl reload nginx" {
		t.Fatalf("rollback commands = %v", commands)
	}
}

func TestDeployExistingCertificateSkipsIssueAndIsIdempotent(t *testing.T) {
	root := t.TempDir()
	site, err := RenderSite(profile(t, "vless-ws-tls"))
	if err != nil {
		t.Fatal(err)
	}
	writeFixtureFile(t, filepath.Join(root, "etc/nginx/xray/example.com.conf"), site)
	writeFixtureFile(t, filepath.Join(root, "etc/nginx/xray/example.com.conf.add"), "")
	writeFixtureFile(t, filepath.Join(root, CertificatePath("example.com")), "certificate")
	writeFixtureFile(t, filepath.Join(root, PrivateKeyPath("example.com")), "private-key")
	runner := &systemexec.RecordingRunner{}
	deployer, err := NewDeployer(DeployOptions{Root: root, Runner: runner})
	if err != nil {
		t.Fatal(err)
	}
	result, err := deployer.Deploy(context.Background(), profile(t, "vless-ws-tls"))
	if err != nil {
		t.Fatal(err)
	}
	if !result.Idempotent || result.CertificateIssued || result.RouteAdded {
		t.Fatalf("result = %+v", result)
	}
	commands := strings.Join(runner.Strings(), "\n")
	if strings.Contains(commands, "certbot certonly") || strings.Contains(commands, "certbot renew --dry-run") {
		t.Fatalf("certificate was needlessly requested:\n%s", commands)
	}
}

func TestDeployDryRunDoesNotWrite(t *testing.T) {
	root := t.TempDir()
	runner := &systemexec.RecordingRunner{}
	deployer, err := NewDeployer(DeployOptions{Root: root, DryRun: true, Runner: runner, ACME: acme.Config{NoEmail: true}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := deployer.Deploy(context.Background(), profile(t, "vless-ws-tls")); err != nil {
		t.Fatal(err)
	}
	entries, err := os.ReadDir(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Fatalf("dry-run wrote files: %v", entries)
	}
	commands := strings.Join(runner.Strings(), "\n")
	if !strings.Contains(commands, "certbot certonly --webroot") || !strings.Contains(commands, "certbot renew --dry-run") {
		t.Fatalf("dry-run plan incomplete:\n%s", commands)
	}
}

func TestDeployDryRunUsesExistingCertificateWithoutACMEConfig(t *testing.T) {
	root := t.TempDir()
	writeFixtureFile(t, filepath.Join(root, CertificatePath("example.com")), "certificate")
	writeFixtureFile(t, filepath.Join(root, PrivateKeyPath("example.com")), "private-key")
	runner := &systemexec.RecordingRunner{}
	deployer, err := NewDeployer(DeployOptions{Root: root, DryRun: true, Runner: runner})
	if err != nil {
		t.Fatal(err)
	}
	result, err := deployer.Deploy(context.Background(), profile(t, "vless-ws-tls"))
	if err != nil {
		t.Fatal(err)
	}
	if result.CertificateIssued {
		t.Fatalf("existing certificate was needlessly issued: %+v", result)
	}
	commands := strings.Join(runner.Strings(), "\n")
	if strings.Contains(commands, "certbot certonly") {
		t.Fatalf("existing certificate was needlessly requested:\n%s", commands)
	}
}

func TestDeployCriticalCommandFailuresRollback(t *testing.T) {
	steps := []int{0, 5, 6, 7, 8, 9, 13, 14, 15, 18}
	for _, failureIndex := range steps {
		t.Run(fmt.Sprintf("command-%d", failureIndex), func(t *testing.T) {
			root := t.TempDir()
			runner := &systemexec.RecordingRunner{
				Failures: map[int]error{failureIndex: errors.New("injected failure")},
				Results:  map[int]systemexec.Result{16: {Stdout: "certbot.timer enabled\n"}},
			}
			runner.AfterRun = func(_ int, command systemexec.Command) {
				if !strings.HasPrefix(command.String(), "certbot certonly") {
					return
				}
				writeFixtureFile(t, filepath.Join(root, CertificatePath("example.com")), "certificate")
				writeFixtureFile(t, filepath.Join(root, PrivateKeyPath("example.com")), "private-key")
				writeFixtureFile(t, filepath.Join(root, "etc/letsencrypt/renewal/example.com.conf"), "[renewalparams]\nauthenticator = webroot\n")
			}
			deployer, err := NewDeployer(DeployOptions{Root: root, Runner: runner, ACME: acme.Config{Email: "user@example.com"}})
			if err != nil {
				t.Fatal(err)
			}
			_, err = deployer.Deploy(context.Background(), profile(t, "vless-ws-tls"))
			if err == nil || !strings.Contains(err.Error(), "injected failure") {
				t.Fatalf("failure %d error = %v", failureIndex, err)
			}
			sitePath := filepath.Join(root, "etc/nginx/xray/example.com.conf")
			if _, statErr := os.Stat(sitePath); !errors.Is(statErr, os.ErrNotExist) {
				t.Fatalf("failure %d left site behind: %v", failureIndex, statErr)
			}
		})
	}
}

func writeFixtureFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
