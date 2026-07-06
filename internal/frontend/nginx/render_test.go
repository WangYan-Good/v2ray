package nginx

import (
	"os"
	"strings"
	"testing"

	"github.com/WangYan-Good/xray/internal/protocol"
)

func profile(t *testing.T, name string) protocol.Profile {
	t.Helper()
	p, err := protocol.ProfileByName(name)
	if err != nil {
		t.Fatal(err)
	}
	return p
}

func fixture(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile("../../../tests/fixtures/nginx/" + path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func TestRenderSiteIncludesWebrootAndAddInclude(t *testing.T) {
	out, err := RenderSite(profile(t, "vless-ws-tls"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"server_name example.com;",
		"location /.well-known/acme-challenge/",
		"root /var/www/certbot;",
		"ssl_certificate /etc/nginx/ssl/example.com/fullchain.pem;",
		"location /xray-test",
		"proxy_pass http://127.0.0.1:10002;",
		"proxy_set_header Upgrade $http_upgrade;",
		"include /etc/nginx/xray/example.com.conf.add;",
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("site output missing %q:\n%s", want, out)
		}
	}
}

func TestRenderAddRoutes(t *testing.T) {
	grpc, err := RenderAdd(profile(t, "vless-grpc-tls"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"location /xray-grpc/", "grpc_pass grpc://127.0.0.1:10003;"} {
		if !strings.Contains(grpc, want) {
			t.Fatalf("grpc add missing %q:\n%s", want, grpc)
		}
	}

	xhttp, err := RenderAdd(profile(t, "trojan-xhttp-tls"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"location /xray-test", "proxy_pass http://127.0.0.1:10005;"} {
		if !strings.Contains(xhttp, want) {
			t.Fatalf("xhttp add missing %q:\n%s", want, xhttp)
		}
	}
}

func TestCheckAppendDetectsConflictIdempotentAndAppend(t *testing.T) {
	mainConf := fixture(t, "multi-protocol-domain.conf")
	addConf := fixture(t, "multi-protocol-domain.conf.add")

	conflict, err := CheckAppend(mainConf, addConf, profile(t, "vless-xhttp-tls"))
	if err != nil {
		t.Fatal(err)
	}
	if conflict.Status != AppendConflict || conflict.Path != "/xray-test" || conflict.ExistingPort == conflict.WantedPort {
		t.Fatalf("conflict = %+v", conflict)
	}

	same, err := CheckAppend(mainConf, addConf, profile(t, "vless-grpc-tls"))
	if err != nil {
		t.Fatal(err)
	}
	if same.Status != AppendSame || same.ExistingPort != 10003 {
		t.Fatalf("same = %+v", same)
	}

	next := profile(t, "vless-xhttp-tls")
	next.Path = "/fresh-xhttp"
	allowed, err := CheckAppend(mainConf, addConf, next)
	if err != nil {
		t.Fatal(err)
	}
	if allowed.Status != AppendAllowed || allowed.Path != "/fresh-xhttp" {
		t.Fatalf("allowed = %+v", allowed)
	}
}

func TestEnsureAddInclude(t *testing.T) {
	content := strings.Replace(fixture(t, "single-domain.conf"), "    include /etc/nginx/xray/example.com.conf.add;\n", "", 1)
	out, changed, err := EnsureAddInclude(content, "/etc/nginx/xray/example.com.conf.add")
	if err != nil {
		t.Fatal(err)
	}
	if !changed {
		t.Fatal("expected include repair")
	}
	if !strings.Contains(out, "include /etc/nginx/xray/example.com.conf.add;") {
		t.Fatalf("repaired config missing include:\n%s", out)
	}
}

func TestCertbotRenewalWebrootMigration(t *testing.T) {
	webroot, err := os.ReadFile("../../../tests/fixtures/certbot/renewal-webroot.conf")
	if err != nil {
		t.Fatal(err)
	}
	if !RenewalUsesWebroot(string(webroot), "example.com") {
		t.Fatalf("webroot renewal not accepted:\n%s", webroot)
	}

	standalone, err := os.ReadFile("../../../tests/fixtures/certbot/renewal-standalone.conf")
	if err != nil {
		t.Fatal(err)
	}
	if RenewalAuthenticator(string(standalone)) != "standalone" {
		t.Fatalf("standalone authenticator not detected")
	}
	migrated, changed := EnsureWebrootRenewal(string(standalone), "example.com")
	if !changed {
		t.Fatal("expected standalone migration")
	}
	for _, want := range []string{
		"authenticator = webroot",
		"webroot_path = /var/www/certbot,",
		"[[webroot_map]]",
		"example.com = /var/www/certbot",
	} {
		if !strings.Contains(migrated, want) {
			t.Fatalf("migrated renewal missing %q:\n%s", want, migrated)
		}
	}
}

func TestOperationPlan(t *testing.T) {
	commands := OperationPlan("example.com")
	got := make([]string, 0, len(commands))
	for _, command := range commands {
		got = append(got, command.String())
	}
	joined := strings.Join(got, "\n")
	for _, want := range []string{
		"nginx -t",
		"certbot certonly --webroot -w /var/www/certbot -d example.com",
		"certbot renew --dry-run --deploy-hook systemctl reload nginx",
		"systemctl reload nginx",
	} {
		if !strings.Contains(joined, want) {
			t.Fatalf("operation plan missing %q:\n%s", want, joined)
		}
	}
}
