package caddy

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
	data, err := os.ReadFile("../../../tests/fixtures/caddy/" + path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func TestRenderSiteIncludesImportAndReverseProxy(t *testing.T) {
	out, err := RenderSite(profile(t, "vless-xhttp-tls"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"example.com {",
		"encode gzip",
		"reverse_proxy /xray-test 127.0.0.1:10004",
		"import /etc/caddy/WangYan-Good/example.com.conf.add",
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
	if !strings.Contains(grpc, "reverse_proxy /xray-grpc/* h2c://127.0.0.1:10003") {
		t.Fatalf("grpc add = %s", grpc)
	}

	xhttp, err := RenderAdd(profile(t, "trojan-xhttp-tls"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(xhttp, "reverse_proxy /xray-test 127.0.0.1:10005") {
		t.Fatalf("xhttp add = %s", xhttp)
	}
}

func TestCheckAppendDetectsConflictIdempotentAndAppend(t *testing.T) {
	mainConf := fixture(t, "single-domain.conf")
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

func TestEnsureAddImport(t *testing.T) {
	content := strings.Replace(fixture(t, "single-domain.conf"), "    import /etc/caddy/WangYan-Good/example.com.conf.add\n", "", 1)
	out, changed, err := EnsureAddImport(content, "/etc/caddy/WangYan-Good/example.com.conf.add")
	if err != nil {
		t.Fatal(err)
	}
	if !changed {
		t.Fatal("expected import repair")
	}
	if !strings.Contains(out, "import /etc/caddy/WangYan-Good/example.com.conf.add") {
		t.Fatalf("repaired config missing import:\n%s", out)
	}
}

func TestOperationPlan(t *testing.T) {
	commands := OperationPlan()
	got := make([]string, 0, len(commands))
	for _, command := range commands {
		got = append(got, command.String())
	}
	joined := strings.Join(got, "\n")
	for _, want := range []string{
		"caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile",
		"systemctl reload caddy",
	} {
		if !strings.Contains(joined, want) {
			t.Fatalf("operation plan missing %q:\n%s", want, joined)
		}
	}
}
