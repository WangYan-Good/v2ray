package app

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	systemexec "github.com/WangYan-Good/xray/internal/system"
)

const fixtureDir = "../../tests/fixtures/xray-conf"

func run(args ...string) (int, string, string) {
	var stdout, stderr bytes.Buffer
	code := Run(args, &stdout, &stderr)
	return code, stdout.String(), stderr.String()
}

func runWithRunner(runner systemexec.Runner, args ...string) (int, string, string) {
	var stdout, stderr bytes.Buffer
	code := RunWithRunner(args, nil, &stdout, &stderr, runner)
	return code, stdout.String(), stderr.String()
}

func installNginxFixture(t *testing.T, dir string) {
	t.Helper()
	code, out, errOut := run("--root", dir, "install", "--skip-core", "--tls", "nginx", "--acme-email", "user@example.com")
	if code != ExitOK {
		t.Fatalf("install code = %d stdout = %s stderr = %s", code, out, errOut)
	}
}

func TestVersionAlias(t *testing.T) {
	code, out, errOut := run("v")
	if code != ExitOK {
		t.Fatalf("code = %d stderr = %s", code, errOut)
	}
	if !strings.Contains(out, "xray go-cli dev") {
		t.Fatalf("version output = %s", out)
	}
}

func TestStatusWithFixtureDir(t *testing.T) {
	code, out, errOut := run("--conf-dir", fixtureDir, "status")
	if code != ExitOK {
		t.Fatalf("code = %d stderr = %s", code, errOut)
	}
	if !strings.Contains(out, "node_count = 8") {
		t.Fatalf("status output = %s", out)
	}
}

func TestInfoReality(t *testing.T) {
	code, out, errOut := run("--conf-dir", fixtureDir, "info", "vless-reality")
	if code != ExitOK {
		t.Fatalf("code = %d stderr = %s", code, errOut)
	}
	for _, want := range []string{
		"protocol = vless",
		"security = reality",
		"serverName = www.microsoft.com",
		"publicKey = example-public-key",
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("info output missing %q:\n%s", want, out)
		}
	}
}

func TestURLXHTTP(t *testing.T) {
	code, out, errOut := run("--conf-dir", fixtureDir, "url", "vless-xhttp")
	if code != ExitOK {
		t.Fatalf("code = %d stderr = %s", code, errOut)
	}
	for _, want := range []string{"vless://", "security=tls", "type=xhttp", "path=%2Fxray-test"} {
		if !strings.Contains(out, want) {
			t.Fatalf("url output missing %q: %s", want, out)
		}
	}
}

func TestUnknownCommandIsNotDelegated(t *testing.T) {
	code, _, errOut := run("definitely-missing")
	if code != ExitUsage {
		t.Fatalf("code = %d stderr = %s", code, errOut)
	}
	if !strings.Contains(errOut, "unknown command") {
		t.Fatalf("stderr = %s", errOut)
	}
}

func TestAddCommandUsesGoRuntime(t *testing.T) {
	dir := t.TempDir()
	installNginxFixture(t, dir)
	code, out, errOut := run("--root", dir, "add", "vws", "example.com")
	if code != ExitOK {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	if !strings.Contains(out, "added = VLESS-WS-TLS-example.com") {
		t.Fatalf("stdout = %s", out)
	}
	if strings.Contains(errOut, "delegating legacy command") {
		t.Fatalf("stderr = %s", errOut)
	}
	if _, err := os.Stat(filepath.Join(dir, "etc/xray/conf/VLESS-WS-TLS-example.com.json")); err != nil {
		t.Fatal(err)
	}
}

func TestAddRefusesExistingConfig(t *testing.T) {
	dir := t.TempDir()
	installNginxFixture(t, dir)
	code, _, errOut := run("--root", dir, "add", "vws", "example.com")
	if code != ExitOK {
		t.Fatalf("first add code = %d stderr = %s", code, errOut)
	}

	code, out, errOut := run("--root", dir, "add", "vws", "example.com")
	if code != ExitConfig {
		t.Fatalf("second add code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	if !strings.Contains(errOut, "config already exists: VLESS-WS-TLS-example.com.json") {
		t.Fatalf("stderr = %s", errOut)
	}
}

func TestAddWithSameExplicitRouteAndPortIsIdempotent(t *testing.T) {
	dir := t.TempDir()
	installNginxFixture(t, dir)
	args := []string{"--root", dir, "add", "vxhttp", "18431", "11111111-1111-4111-8111-111111111111", "example.com", "/same-route"}
	code, out, errOut := run(args...)
	if code != ExitOK {
		t.Fatalf("first add code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	code, out, errOut = run(args...)
	if code != ExitOK {
		t.Fatalf("idempotent add code = %d stdout = %s stderr = %s", code, out, errOut)
	}

	conflicting := append([]string(nil), args...)
	conflicting[5] = "22222222-2222-4222-8222-222222222222"
	code, out, errOut = run(conflicting...)
	if code != ExitConfig || !strings.Contains(errOut, "config already exists") {
		t.Fatalf("conflicting add code = %d stdout = %s stderr = %s", code, out, errOut)
	}
}

func TestClientFromStoredFrontendKeepsTLS(t *testing.T) {
	dir := t.TempDir()
	installNginxFixture(t, dir)
	code, _, errOut := run("--root", dir, "add", "vws", "example.com")
	if code != ExitOK {
		t.Fatalf("add code = %d stderr = %s", code, errOut)
	}

	code, out, errOut := run("--root", dir, "client", "VLESS-WS-TLS-example.com")
	if code != ExitOK {
		t.Fatalf("client code = %d stderr = %s", code, errOut)
	}
	for _, want := range []string{`"security": "tls"`, `"address": "example.com"`} {
		if !strings.Contains(out, want) {
			t.Fatalf("client output missing %q:\n%s", want, out)
		}
	}
}

func TestInstallWritesNginxInclude(t *testing.T) {
	dir := t.TempDir()
	code, out, errOut := run("--root", dir, "install", "--skip-core", "--tls", "nginx")
	if code != ExitOK {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	data, err := os.ReadFile(filepath.Join(dir, "etc/nginx/conf.d/xray.conf"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "include "+filepath.Join(dir, "etc/nginx/xray")+"/*.conf;") {
		t.Fatalf("nginx include = %s", data)
	}
}

func TestInstallPersistsACMEEmail(t *testing.T) {
	dir := t.TempDir()
	code, out, errOut := run("--root", dir, "install", "--skip-core", "--tls", "nginx", "--acme-email", "user@example.com")
	if code != ExitOK {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	path := filepath.Join(dir, "etc/xray/acme.json")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), `"email": "user@example.com"`) {
		t.Fatalf("ACME config = %s", data)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %o", info.Mode().Perm())
	}
}

func TestInstallEnablesValidatedServices(t *testing.T) {
	dir := t.TempDir()
	code, out, errOut := run("--root", dir, "install", "--skip-core", "--tls", "nginx", "--acme-email", "user@example.com")
	if code != ExitOK {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	ordered := []string{
		filepath.Join(dir, "etc/xray/bin/xray") + " run -test",
		"nginx -t",
		"systemctl daemon-reload",
		"systemctl enable --now xray",
		"systemctl enable --now nginx",
	}
	last := -1
	for _, command := range ordered {
		index := strings.Index(out, command)
		if index <= last {
			t.Fatalf("command %q out of order:\n%s", command, out)
		}
		last = index
	}
}

func TestInstallDryRunWritesNothing(t *testing.T) {
	dir := t.TempDir()
	code, out, errOut := run("--root", dir, "--dry-run", "install", "--skip-core", "--tls", "nginx", "--acme-email", "user@example.com")
	if code != ExitOK {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Fatalf("dry-run wrote files: %v", entries)
	}
	if !strings.Contains(out, "systemctl enable --now nginx") || !strings.Contains(out, "dry_run_file") {
		t.Fatalf("dry-run plan incomplete:\n%s", out)
	}
}

func TestNginxAddRollsBackXrayWhenCertbotFails(t *testing.T) {
	dir := t.TempDir()
	installNginxFixture(t, dir)
	mainBefore, err := os.ReadFile(filepath.Join(dir, "etc/xray/config.json"))
	if err != nil {
		t.Fatal(err)
	}
	runner := &systemexec.RecordingRunner{Failures: map[int]error{11: errors.New("certbot unavailable")}}
	code, out, errOut := runWithRunner(runner, "--root", dir, "add", "vws", "example.com")
	if code != ExitUnexpected || !strings.Contains(errOut, "certbot unavailable") {
		t.Fatalf("code = %d stdout = %s stderr = %s commands = %v", code, out, errOut, runner.Strings())
	}
	nodePath := filepath.Join(dir, "etc/xray/conf/VLESS-WS-TLS-example.com.json")
	if _, err := os.Stat(nodePath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("node was not rolled back: %v", err)
	}
	mainAfter, err := os.ReadFile(filepath.Join(dir, "etc/xray/config.json"))
	if err != nil || !bytes.Equal(mainBefore, mainAfter) {
		t.Fatalf("main config was not restored: %v", err)
	}
	commands := runner.Strings()
	if commands[len(commands)-1] != "systemctl restart xray" {
		t.Fatalf("Xray rollback was not attempted: %v", commands)
	}
}

func TestNonTLSAddDoesNotCallNginxOrCertbot(t *testing.T) {
	dir := t.TempDir()
	runner := &systemexec.RecordingRunner{}
	code, out, errOut := runWithRunner(runner, "--root", dir, "add", "ss", "31004", "example-password", "aes-128-gcm")
	if code != ExitOK {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	commands := strings.Join(runner.Strings(), "\n")
	if strings.Contains(commands, "nginx") || strings.Contains(commands, "certbot") {
		t.Fatalf("non-TLS commands:\n%s", commands)
	}
}

func TestCaddyInstallDoesNotStartNginx(t *testing.T) {
	dir := t.TempDir()
	code, out, errOut := run("--root", dir, "install", "--skip-core", "--tls", "caddy")
	if code != ExitOK {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	if strings.Contains(out, "nginx") || strings.Contains(out, "certbot") {
		t.Fatalf("Caddy install touched Nginx/Certbot:\n%s", out)
	}
}

func TestFixNginxfileRepairsWebrootRenewal(t *testing.T) {
	dir := t.TempDir()
	siteDir := filepath.Join(dir, "etc/nginx/xray")
	renewalDir := filepath.Join(dir, "etc/letsencrypt/renewal")
	if err := os.MkdirAll(siteDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(renewalDir, 0o755); err != nil {
		t.Fatal(err)
	}
	sitePath := filepath.Join(siteDir, "bak.proxy.yourdie.com.conf")
	site := `server {
    if ($host = bak.proxy.yourdie.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    listen 80;
    server_name bak.proxy.yourdie.com;
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    location / {
        return 301 https://$server_name$request_uri;
    }
}
`
	if err := os.WriteFile(sitePath, []byte(site), 0o644); err != nil {
		t.Fatal(err)
	}
	renewalPath := filepath.Join(renewalDir, "bak.proxy.yourdie.com.conf")
	renewal := "[renewalparams]\nauthenticator = nginx\ninstaller = nginx\n"
	if err := os.WriteFile(renewalPath, []byte(renewal), 0o600); err != nil {
		t.Fatal(err)
	}

	code, out, errOut := run("--root", dir, "fix-nginxfile")
	if code != ExitOK {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	repairedSite, err := os.ReadFile(sitePath)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(repairedSite), "managed by Certbot") {
		t.Fatalf("certbot redirect was not removed:\n%s", repairedSite)
	}
	repairedRenewal, err := os.ReadFile(renewalPath)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"authenticator = webroot",
		"webroot_path = /var/www/certbot,",
		"bak.proxy.yourdie.com = /var/www/certbot",
	} {
		if !strings.Contains(string(repairedRenewal), want) {
			t.Fatalf("renewal missing %q:\n%s", want, repairedRenewal)
		}
	}
	if strings.Contains(string(repairedRenewal), "installer = nginx") {
		t.Fatalf("nginx installer should be removed:\n%s", repairedRenewal)
	}
	info, err := os.Stat(renewalPath)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("renewal mode = %v", info.Mode().Perm())
	}
}

func TestConfigTestUsesConfdir(t *testing.T) {
	dir := t.TempDir()
	code, out, errOut := run("--root", dir, "test")
	if code != ExitOK {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	for _, want := range []string{
		filepath.Join(dir, "etc/xray/bin/xray") + " run -test",
		"-config " + filepath.Join(dir, "etc/xray/config.json"),
		"-confdir " + filepath.Join(dir, "etc/xray/conf"),
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("dry-run output missing %q:\n%s", want, out)
		}
	}
}

func TestServerOverrideDoesNotInventFrontendTLS(t *testing.T) {
	dir := t.TempDir()
	code, _, errOut := run("--root", dir, "add", "ss", "31004", "accept-ss-password", "aes-128-gcm")
	if code != ExitOK {
		t.Fatalf("add code = %d stderr = %s", code, errOut)
	}

	code, out, errOut := run("--root", dir, "--server", "bak.proxy.yourdie.com", "info", "Shadowsocks-31004")
	if code != ExitOK {
		t.Fatalf("info code = %d stderr = %s", code, errOut)
	}
	for _, want := range []string{
		"address = bak.proxy.yourdie.com",
		"port = 31004",
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("info output missing %q:\n%s", want, out)
		}
	}
	for _, unwanted := range []string{
		"host = bak.proxy.yourdie.com",
		"security = tls",
	} {
		if strings.Contains(out, unwanted) {
			t.Fatalf("info output should not contain %q:\n%s", unwanted, out)
		}
	}
}

func TestRefreshSubWritesExactNginxLocation(t *testing.T) {
	dir := t.TempDir()
	code, out, errOut := run("--root", dir, "install", "--skip-core")
	if code != ExitOK {
		t.Fatalf("install code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	code, out, errOut = run("--root", dir, "refresh-sub", "bak.proxy.yourdie.com")
	if code != ExitOK {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	data, err := os.ReadFile(filepath.Join(dir, "etc/nginx/xray/bak.proxy.yourdie.com.conf.add"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	if !strings.Contains(text, "location = /sub/") {
		t.Fatalf("subscription route should be exact match:\n%s", text)
	}
	if !strings.Contains(text, "alias "+filepath.Join(dir, "etc/xray/sub/mihomo.yaml")+";") {
		t.Fatalf("subscription route missing alias:\n%s", text)
	}
}

func TestUpdateCommandIsRecognizedWithoutLegacyPath(t *testing.T) {
	dir := t.TempDir()
	code, _, errOut := run("--root", dir, "update", "go")
	if code != ExitOK {
		t.Fatalf("code = %d stderr = %s", code, errOut)
	}
	if strings.Contains(errOut, "legacy command requires Bash entry") {
		t.Fatalf("stderr = %s", errOut)
	}
}

func TestGenXrayReality(t *testing.T) {
	code, out, errOut := run("gen", "--format", "xray", "vless-reality")
	if code != ExitOK {
		t.Fatalf("code = %d stderr = %s", code, errOut)
	}
	for _, want := range []string{
		`"protocol": "vless"`,
		`"security": "reality"`,
		`"flow": "xtls-rprx-vision"`,
		`"serverNames": [`,
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("gen xray output missing %q:\n%s", want, out)
		}
	}
}

func TestGenMihomoDefault(t *testing.T) {
	code, out, errOut := run("gen", "--format", "mihomo")
	if code != ExitOK {
		t.Fatalf("code = %d stderr = %s", code, errOut)
	}
	for _, want := range []string{"reality-opts:", "xhttp-opts:", "type: ss", "type: socks5", "skip \"Trojan-XHTTP-TLS-example.com\""} {
		if !strings.Contains(out, want) {
			t.Fatalf("gen mihomo output missing %q:\n%s", want, out)
		}
	}
}

func TestGenUnsupportedMihomoSingleNode(t *testing.T) {
	code, out, errOut := run("gen", "--format", "mihomo", "trojan-xhttp-tls")
	if code != ExitUnsupported {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	if !strings.Contains(errOut, "mihomo trojan transport supports ws/grpc/tcp only") {
		t.Fatalf("stderr = %s", errOut)
	}
}

func TestGenFrontendTemplates(t *testing.T) {
	tests := []struct {
		args []string
		want []string
	}{
		{
			args: []string{"gen", "--format", "nginx", "vless-ws-tls"},
			want: []string{
				"location ^~ /.well-known/acme-challenge/",
				"proxy_pass http://127.0.0.1:10002;",
				"include /etc/nginx/xray/example.com.conf.add;",
			},
		},
		{
			args: []string{"gen", "--format", "nginx-add", "vless-grpc-tls"},
			want: []string{"location /xray-grpc/", "grpc_pass grpc://127.0.0.1:10003;"},
		},
		{
			args: []string{"gen", "--format", "caddy", "vless-xhttp-tls"},
			want: []string{"reverse_proxy /xray-test 127.0.0.1:10004", "import /etc/caddy/WangYan-Good/example.com.conf.add"},
		},
		{
			args: []string{"gen", "--format", "caddy-add", "trojan-xhttp-tls"},
			want: []string{"reverse_proxy /xray-test 127.0.0.1:10005"},
		},
	}

	for _, tt := range tests {
		code, out, errOut := run(tt.args...)
		if code != ExitOK {
			t.Fatalf("%v code = %d stderr = %s", tt.args, code, errOut)
		}
		for _, want := range tt.want {
			if !strings.Contains(out, want) {
				t.Fatalf("%v output missing %q:\n%s", tt.args, want, out)
			}
		}
	}
}

func TestGenFrontendRejectsDirectProtocol(t *testing.T) {
	code, out, errOut := run("gen", "--format", "nginx", "vless-reality")
	if code != ExitUnsupported {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	if !strings.Contains(errOut, "no TLS frontend host") {
		t.Fatalf("stderr = %s", errOut)
	}
}

func TestDownloadPlanCore(t *testing.T) {
	code, out, errOut := run("download-plan", "--version", "v1.8.24", "--arch", "x86_64", "--proxy", "http://127.0.0.1:7890", "core")
	if code != ExitOK {
		t.Fatalf("code = %d stderr = %s", code, errOut)
	}
	for _, want := range []string{
		"kind = core",
		"asset.0.name = Xray-linux-64.zip",
		"asset.0.checksum_url = https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip.dgst",
		"proxy.http_proxy = http://127.0.0.1:7890",
		"install_step.0 = create /etc/xray/bin",
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("download plan missing %q:\n%s", want, out)
		}
	}
}

func TestDownloadPlanUnsupportedArch(t *testing.T) {
	code, out, errOut := run("download-plan", "--arch", "riscv64", "core")
	if code != ExitConfig {
		t.Fatalf("code = %d stdout = %s stderr = %s", code, out, errOut)
	}
	if !strings.Contains(errOut, "unsupported architecture: riscv64") {
		t.Fatalf("stderr = %s", errOut)
	}
}

func TestSwitchPlan(t *testing.T) {
	code, out, errOut := run("switch-plan")
	if code != ExitOK {
		t.Fatalf("code = %d stderr = %s", code, errOut)
	}
	for _, want := range []string{
		"mode = go",
		"entry = /usr/local/bin/xray",
		"runtime = go",
		"install = install.sh downloads xray-linux-{arch}.tar.gz and verifies checksums.txt",
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("switch plan missing %q:\n%s", want, out)
		}
	}
}
