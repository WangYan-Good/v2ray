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
		"location ^~ /.well-known/acme-challenge/",
		"root /var/www/certbot;",
		"try_files $uri =404;",
		"ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;",
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

func TestRenderBootstrapHasNoTLSDependency(t *testing.T) {
	out, err := RenderBootstrap("example.com")
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"listen 80;",
		"listen [::]:80;",
		"location ^~ /.well-known/acme-challenge/",
		"try_files $uri =404;",
		`return 503 "TLS certificate provisioning in progress\n";`,
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("bootstrap missing %q:\n%s", want, out)
		}
	}
	for _, unwanted := range []string{"listen 443", "ssl_certificate", "return 301"} {
		if strings.Contains(out, unwanted) {
			t.Fatalf("bootstrap contains %q:\n%s", unwanted, out)
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

func TestEnsureHTTPInclude(t *testing.T) {
	content := "events {}\nhttp {\n    server { listen 80; }\n}\n"
	out, changed, err := EnsureHTTPInclude(content, "/etc/nginx/conf.d/xray.conf")
	if err != nil || !changed {
		t.Fatalf("changed = %v, error = %v", changed, err)
	}
	if !strings.Contains(out, "include /etc/nginx/conf.d/xray.conf;") {
		t.Fatalf("output = %s", out)
	}
	unchanged, changed, err := EnsureHTTPInclude("http { include /etc/nginx/conf.d/*.conf; }\n", "/etc/nginx/conf.d/xray.conf")
	if err != nil || changed || unchanged == "" {
		t.Fatalf("wildcard include changed = %v, error = %v", changed, err)
	}
	direct := "http {\n    include /etc/nginx/xray/*.conf;\n}\n"
	unchanged, changed, err = EnsureHTTPInclude(direct, "/etc/nginx/conf.d/xray.conf")
	if err != nil || changed || unchanged != direct {
		t.Fatalf("direct managed-site include changed = %v, error = %v", changed, err)
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

func TestCertificatePathMigrationRequiresVerifiedCertificate(t *testing.T) {
	legacy := "ssl_certificate /etc/nginx/ssl/example.com/fullchain.pem;\nssl_certificate_key /etc/nginx/ssl/example.com/privkey.pem;\n"
	unchanged, changed, warning := MigrateCertificatePaths(legacy, "example.com", false)
	if changed || unchanged != legacy || warning == "" {
		t.Fatalf("unverified migration = %q, %v, %q", unchanged, changed, warning)
	}
	migrated, changed, warning := MigrateCertificatePaths(legacy, "example.com", true)
	if !changed || warning != "" || strings.Contains(migrated, "/etc/nginx/ssl/") {
		t.Fatalf("verified migration = %q, %v, %q", migrated, changed, warning)
	}
	if !strings.Contains(migrated, "/etc/letsencrypt/live/example.com/fullchain.pem") {
		t.Fatalf("migrated = %s", migrated)
	}
}

func TestValidateDomain(t *testing.T) {
	for _, valid := range []string{"example.com", "xn--fsqu00a.xn--0zwm56d", "a-b.example.com"} {
		if err := ValidateDomain(valid); err != nil {
			t.Fatalf("%s: %v", valid, err)
		}
	}
	for _, invalid := range []string{"127.0.0.1", "2001:db8::1", "localhost", "-bad.example.com"} {
		if err := ValidateDomain(invalid); err == nil {
			t.Fatalf("expected %s to be invalid", invalid)
		}
	}
}

func TestRemoveManagedCertbotRedirectsIsDomainScoped(t *testing.T) {
	content := `server {
    if ($host = example.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    if ($host = custom.example.com) {
        return 302 https://elsewhere.invalid;
    }
}
`
	out, changed := RemoveManagedCertbotRedirects(content, "example.com")
	if !changed || strings.Contains(out, "managed by Certbot") {
		t.Fatalf("managed block not removed:\n%s", out)
	}
	if !strings.Contains(out, "custom.example.com") {
		t.Fatalf("custom block was removed:\n%s", out)
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
		"certbot certonly --webroot -w /var/www/certbot -d example.com --cert-name example.com --non-interactive --agree-tos --keep-until-expiring",
		"certbot renew --dry-run",
		"systemctl reload nginx",
	} {
		if !strings.Contains(joined, want) {
			t.Fatalf("operation plan missing %q:\n%s", want, joined)
		}
	}
}
