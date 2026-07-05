package app

import (
	"bytes"
	"strings"
	"testing"
)

const fixtureDir = "../../tests/fixtures/xray-conf"

func run(args ...string) (int, string, string) {
	var stdout, stderr bytes.Buffer
	code := Run(args, &stdout, &stderr)
	return code, stdout.String(), stderr.String()
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

func TestUnknownCommand(t *testing.T) {
	code, _, errOut := run("add")
	if code != ExitUsage {
		t.Fatalf("code = %d stderr = %s", code, errOut)
	}
	if !strings.Contains(errOut, "unknown command") {
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
				"location /.well-known/acme-challenge/",
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
