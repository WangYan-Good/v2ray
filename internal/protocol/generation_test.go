package protocol

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"
)

func TestDefaultProfilesCoverFixtures(t *testing.T) {
	want := []string{
		"shadowsocks",
		"socks",
		"trojan-ws-tls",
		"trojan-xhttp-tls",
		"vless-grpc-tls",
		"vless-reality",
		"vless-ws-tls",
		"vless-xhttp-tls",
		"vmess-tcp",
		"vmess-ws-tls",
	}
	got := ProfileNames()
	if strings.Join(got, ",") != strings.Join(want, ",") {
		t.Fatalf("ProfileNames() = %v, want %v", got, want)
	}
	for _, name := range want {
		profile, err := ProfileByName(name)
		if err != nil {
			t.Fatalf("ProfileByName(%q): %v", name, err)
		}
		if err := profile.Validate(); err != nil {
			t.Fatalf("%s Validate(): %v", name, err)
		}
	}
}

func TestXrayJSONMatchesFixtureFields(t *testing.T) {
	cases := []struct {
		profile string
		fixture string
		paths   [][]string
	}{
		{
			profile: "vless-reality",
			fixture: "vless-reality.json",
			paths: [][]string{
				path("inbounds", "0", "settings", "clients", "0", "id"),
				path("inbounds", "0", "settings", "clients", "0", "flow"),
				path("inbounds", "0", "settings", "decryption"),
				path("inbounds", "0", "streamSettings", "network"),
				path("inbounds", "0", "streamSettings", "security"),
				path("inbounds", "0", "streamSettings", "realitySettings", "serverNames", "0"),
				path("inbounds", "0", "streamSettings", "realitySettings", "privateKey"),
				path("inbounds", "0", "streamSettings", "realitySettings", "publicKey"),
			},
		},
		{
			profile: "vless-ws-tls",
			fixture: "vless-ws-tls.json",
			paths: [][]string{
				path("inbounds", "0", "streamSettings", "network"),
				path("inbounds", "0", "streamSettings", "security"),
				path("inbounds", "0", "streamSettings", "wsSettings", "path"),
				path("inbounds", "0", "streamSettings", "wsSettings", "headers", "Host"),
			},
		},
		{
			profile: "vless-grpc-tls",
			fixture: "vless-grpc-tls.json",
			paths: [][]string{
				path("inbounds", "0", "streamSettings", "network"),
				path("inbounds", "0", "streamSettings", "security"),
				path("inbounds", "0", "streamSettings", "grpcSettings", "serviceName"),
			},
		},
		{
			profile: "vless-xhttp-tls",
			fixture: "vless-xhttp-tls.json",
			paths: [][]string{
				path("inbounds", "0", "streamSettings", "network"),
				path("inbounds", "0", "streamSettings", "security"),
				path("inbounds", "0", "streamSettings", "xhttpSettings", "host"),
				path("inbounds", "0", "streamSettings", "xhttpSettings", "path"),
				path("inbounds", "0", "streamSettings", "xhttpSettings", "mode"),
			},
		},
		{
			profile: "trojan-xhttp-tls",
			fixture: "trojan-xhttp-tls.json",
			paths: [][]string{
				path("inbounds", "0", "settings", "clients", "0", "password"),
				path("inbounds", "0", "streamSettings", "network"),
				path("inbounds", "0", "streamSettings", "security"),
				path("inbounds", "0", "streamSettings", "xhttpSettings", "mode"),
			},
		},
		{
			profile: "vmess-tcp",
			fixture: "vmess-tcp.json",
			paths: [][]string{
				path("inbounds", "0", "settings", "clients", "0", "id"),
				path("inbounds", "0", "settings", "clients", "0", "alterId"),
				path("inbounds", "0", "streamSettings", "network"),
				path("inbounds", "0", "streamSettings", "tcpSettings", "header", "type"),
			},
		},
		{
			profile: "shadowsocks",
			fixture: "shadowsocks.json",
			paths: [][]string{
				path("inbounds", "0", "settings", "method"),
				path("inbounds", "0", "settings", "password"),
				path("inbounds", "0", "settings", "network"),
			},
		},
		{
			profile: "socks",
			fixture: "socks.json",
			paths: [][]string{
				path("inbounds", "0", "settings", "auth"),
				path("inbounds", "0", "settings", "accounts", "0", "user"),
				path("inbounds", "0", "settings", "accounts", "0", "pass"),
				path("inbounds", "0", "settings", "udp"),
			},
		},
	}

	for _, tt := range cases {
		t.Run(tt.profile, func(t *testing.T) {
			profile, err := ProfileByName(tt.profile)
			if err != nil {
				t.Fatal(err)
			}
			generated, err := XrayJSON(profile)
			if err != nil {
				t.Fatal(err)
			}
			got := decodeJSON(t, generated)
			want := decodeFixture(t, tt.fixture)

			for _, common := range [][]string{
				path("inbounds", "0", "protocol"),
				path("inbounds", "0", "port"),
				path("inbounds", "0", "listen"),
			} {
				assertSamePath(t, got, want, common)
			}
			for _, p := range tt.paths {
				assertSamePath(t, got, want, p)
			}
		})
	}
}

func TestClientJSONContainsPublicConnectionFields(t *testing.T) {
	xhttp, err := ProfileByName("vless-xhttp-tls")
	if err != nil {
		t.Fatal(err)
	}
	data, err := ClientJSON(xhttp)
	if err != nil {
		t.Fatal(err)
	}
	doc := decodeJSON(t, data)
	assertJSONValue(t, doc, path("outbounds", "0", "settings", "vnext", "0", "address"), "example.com")
	assertJSONValue(t, doc, path("outbounds", "0", "settings", "vnext", "0", "port"), "443")
	assertJSONValue(t, doc, path("outbounds", "0", "streamSettings", "security"), "tls")
	assertJSONValue(t, doc, path("outbounds", "0", "streamSettings", "xhttpSettings", "path"), "/xray-test")

	ss, err := ProfileByName("shadowsocks")
	if err != nil {
		t.Fatal(err)
	}
	data, err = ClientJSON(ss)
	if err != nil {
		t.Fatal(err)
	}
	doc = decodeJSON(t, data)
	assertJSONValue(t, doc, path("outbounds", "0", "settings", "servers", "0", "address"), "203.0.113.10")
	assertJSONValue(t, doc, path("outbounds", "0", "settings", "servers", "0", "port"), "10007")
	assertJSONValue(t, doc, path("outbounds", "0", "settings", "servers", "0", "method"), "aes-256-gcm")
	assertJSONValue(t, doc, path("outbounds", "0", "settings", "servers", "0", "password"), "example-password")

	vmess, err := ProfileByName("vmess-tcp")
	if err != nil {
		t.Fatal(err)
	}
	vmess.Host = "bak.proxy.yourdie.com"
	data, err = ClientJSON(vmess)
	if err != nil {
		t.Fatal(err)
	}
	doc = decodeJSON(t, data)
	assertJSONValue(t, doc, path("outbounds", "0", "settings", "vnext", "0", "address"), "bak.proxy.yourdie.com")
	if strings.Contains(string(data), `"security": "tls"`) {
		t.Fatalf("vmess tcp client must not enable TLS just because a server address is set:\n%s", data)
	}
}

func TestMihomoDocumentContainsSupportedNodesAndSkip(t *testing.T) {
	out, err := MihomoDocument(DefaultProfiles())
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"type: vless",
		"reality-opts:",
		"network: ws",
		"network: grpc",
		"network: xhttp",
		"xhttp-opts:",
		"type: vmess",
		"type: ss",
		"type: socks5",
		"skip \"Trojan-XHTTP-TLS-example.com\"",
		"proxy-groups:",
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("mihomo output missing %q:\n%s", want, out)
		}
	}
}

func decodeFixture(t *testing.T, name string) any {
	t.Helper()
	data, err := os.ReadFile("../../tests/fixtures/xray-conf/" + name)
	if err != nil {
		t.Fatal(err)
	}
	return decodeJSON(t, data)
}

func decodeJSON(t *testing.T, data []byte) any {
	t.Helper()
	var doc any
	if err := json.Unmarshal(data, &doc); err != nil {
		t.Fatalf("decode json: %v\n%s", err, data)
	}
	return doc
}

func path(parts ...string) []string {
	return parts
}

func assertSamePath(t *testing.T, got, want any, p []string) {
	t.Helper()
	gotValue := jsonPath(t, got, p)
	wantValue := jsonPath(t, want, p)
	if gotValue != wantValue {
		t.Fatalf("%s = %q, want %q", strings.Join(p, "."), gotValue, wantValue)
	}
}

func assertJSONValue(t *testing.T, doc any, p []string, want string) {
	t.Helper()
	if got := jsonPath(t, doc, p); got != want {
		t.Fatalf("%s = %q, want %q", strings.Join(p, "."), got, want)
	}
}

func jsonPath(t *testing.T, doc any, p []string) string {
	t.Helper()
	current := doc
	for _, part := range p {
		switch value := current.(type) {
		case map[string]any:
			var ok bool
			current, ok = value[part]
			if !ok {
				t.Fatalf("missing key %s in %v", part, p)
			}
		case []any:
			index, err := strconv.Atoi(part)
			if err != nil {
				t.Fatalf("path %v: %q is not an index", p, part)
			}
			if index < 0 || index >= len(value) {
				t.Fatalf("path %v: index %d out of range", p, index)
			}
			current = value[index]
		default:
			t.Fatalf("path %v reached scalar %T before %q", p, current, part)
		}
	}

	switch value := current.(type) {
	case string:
		return value
	case float64:
		if value == float64(int(value)) {
			return strconv.Itoa(int(value))
		}
		return strconv.FormatFloat(value, 'f', -1, 64)
	case bool:
		return strconv.FormatBool(value)
	case nil:
		return ""
	default:
		return strings.TrimSpace(strings.ReplaceAll(strings.ReplaceAll(fmt.Sprint(value), "\n", " "), "\t", " "))
	}
}
