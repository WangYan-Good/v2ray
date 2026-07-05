package protocol

import (
	"encoding/base64"
	"net/url"
	"strings"
	"testing"

	"github.com/WangYan-Good/xray/internal/config"
)

const fixtureDir = "../../tests/fixtures/xray-conf"

func node(t *testing.T, query string) config.Node {
	t.Helper()
	n, err := config.MatchNode(fixtureDir, query)
	if err != nil {
		t.Fatalf("MatchNode(%q): %v", query, err)
	}
	return n
}

func TestVLESSRealityURL(t *testing.T) {
	raw, err := ShareURL(node(t, "vless-reality"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(raw, "vless://") {
		t.Fatalf("url = %s", raw)
	}
	assertQuery(t, raw, "security", "reality")
	assertQuery(t, raw, "type", "tcp")
	assertQuery(t, raw, "sni", "www.microsoft.com")
	assertQuery(t, raw, "pbk", "example-public-key")
	assertQuery(t, raw, "flow", "xtls-rprx-vision")
	assertQuery(t, raw, "fp", "ios")
}

func TestVLESSTransportURLs(t *testing.T) {
	tests := []struct {
		query string
		typ   string
		key   string
		value string
	}{
		{"vless-ws", "ws", "path", "/xray-test"},
		{"vless-grpc", "grpc", "serviceName", "xray-grpc"},
		{"vless-xhttp", "xhttp", "path", "/xray-test"},
	}
	for _, tt := range tests {
		raw, err := ShareURL(node(t, tt.query))
		if err != nil {
			t.Fatal(err)
		}
		assertQuery(t, raw, "security", "tls")
		assertQuery(t, raw, "type", tt.typ)
		assertQuery(t, raw, "host", "example.com")
		assertQuery(t, raw, tt.key, tt.value)
	}
}

func TestTrojanXHTTPURL(t *testing.T) {
	raw, err := ShareURL(node(t, "trojan-xhttp"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(raw, "trojan://") {
		t.Fatalf("url = %s", raw)
	}
	assertQuery(t, raw, "security", "tls")
	assertQuery(t, raw, "type", "xhttp")
	assertQuery(t, raw, "path", "/xray-test")
}

func TestVMessURL(t *testing.T) {
	raw, err := ShareURL(node(t, "vmess-tcp"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(raw, "vmess://") {
		t.Fatalf("url = %s", raw)
	}
	encoded := strings.TrimPrefix(raw, "vmess://")
	decoded, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		t.Fatalf("decode vmess url: %v", err)
	}
	text := string(decoded)
	for _, want := range []string{`"net":"tcp"`, `"type":"none"`, `"id":"11111111-1111-4111-8111-111111111111"`} {
		if !strings.Contains(text, want) {
			t.Fatalf("vmess payload missing %s: %s", want, text)
		}
	}
}

func TestShadowsocksAndSocksURLs(t *testing.T) {
	ss, err := ShareURL(node(t, "shadowsocks"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(ss, "ss://aes-256-gcm:example-password@203.0.113.10:10007") {
		t.Fatalf("ss url = %s", ss)
	}

	socks, err := ShareURL(node(t, "socks"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(socks, "socks://") || !strings.Contains(socks, "@203.0.113.10:10008") {
		t.Fatalf("socks url = %s", socks)
	}
}

func assertQuery(t *testing.T, raw, key, want string) {
	t.Helper()
	parsed, err := url.Parse(raw)
	if err != nil {
		t.Fatalf("parse url: %v", err)
	}
	if got := parsed.Query().Get(key); got != want {
		t.Fatalf("query %s = %q, want %q in %s", key, got, want, raw)
	}
}
