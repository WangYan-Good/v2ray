package config

import (
	"strings"
	"testing"
)

const fixtureDir = "../../tests/fixtures/xray-conf"

func TestListNodesReadsFixtureConfigs(t *testing.T) {
	nodes, err := ListNodes(fixtureDir)
	if err != nil {
		t.Fatalf("ListNodes returned error: %v", err)
	}
	if got, want := len(nodes), 8; got != want {
		t.Fatalf("node count = %d, want %d", got, want)
	}
}

func TestReadNodeExtractsRealityFields(t *testing.T) {
	node, err := MatchNode(fixtureDir, "vless-reality")
	if err != nil {
		t.Fatalf("MatchNode returned error: %v", err)
	}
	if node.Protocol != "vless" {
		t.Fatalf("protocol = %q", node.Protocol)
	}
	if node.Network != "tcp" {
		t.Fatalf("network = %q", node.Network)
	}
	if node.Security != "reality" {
		t.Fatalf("security = %q", node.Security)
	}
	if node.Flow != "xtls-rprx-vision" {
		t.Fatalf("flow = %q", node.Flow)
	}
	if node.ServerName != "www.microsoft.com" {
		t.Fatalf("serverName = %q", node.ServerName)
	}
	if node.PublicKey != "example-public-key" {
		t.Fatalf("publicKey = %q", node.PublicKey)
	}
}

func TestReadNodeExtractsTransportFields(t *testing.T) {
	tests := []struct {
		query       string
		network     string
		host        string
		path        string
		serviceName string
	}{
		{"vless-ws", "ws", "example.com", "/xray-test", ""},
		{"vless-grpc", "grpc", "example.com", "", "xray-grpc"},
		{"vless-xhttp", "xhttp", "example.com", "/xray-test", ""},
	}
	for _, tt := range tests {
		node, err := MatchNode(fixtureDir, tt.query)
		if err != nil {
			t.Fatalf("%s: %v", tt.query, err)
		}
		if node.Network != tt.network {
			t.Fatalf("%s network = %q, want %q", tt.query, node.Network, tt.network)
		}
		if node.Host != tt.host {
			t.Fatalf("%s host = %q, want %q", tt.query, node.Host, tt.host)
		}
		if node.Path != tt.path {
			t.Fatalf("%s path = %q, want %q", tt.query, node.Path, tt.path)
		}
		if node.ServiceName != tt.serviceName {
			t.Fatalf("%s serviceName = %q, want %q", tt.query, node.ServiceName, tt.serviceName)
		}
	}
}

func TestMatchNodeReportsMultipleMatches(t *testing.T) {
	_, err := MatchNode(fixtureDir, "vless")
	if err == nil {
		t.Fatal("expected multiple match error")
	}
	if !strings.Contains(err.Error(), "multiple configs match") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestMatchNodeReportsMissingConfig(t *testing.T) {
	_, err := MatchNode(fixtureDir, "missing")
	if err == nil {
		t.Fatal("expected missing config error")
	}
	if !strings.Contains(err.Error(), "config not found") {
		t.Fatalf("unexpected error: %v", err)
	}
}
