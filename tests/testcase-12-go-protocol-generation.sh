#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 2 Go protocol generation"

assert_file "docs/10-project-management/phase-2-protocol-generation-plan.md"
assert_file "docs/04-backend/protocol-model-design.md"

run_go() {
    if command -v go >/dev/null 2>&1; then
        go "$@"
        return
    fi

    if command -v docker >/dev/null 2>&1; then
        local image="${GO_CONTAINER_IMAGE:-docker.m.daocloud.io/library/golang:1.22}"
        docker run --rm \
            -v "$REPO_ROOT:/workspace" \
            -w /workspace \
            "$image" \
            go "$@"
        return
    fi

    fail "Go toolchain unavailable: install go or provide docker/podman with golang:1.22"
}

run_xray() {
    run_go run ./cmd/xray "$@"
}

json_value() {
    local file="$1"
    local query="$2"
    jq -r "$query" "$file"
}

compare_fixture_value() {
    local generated="$1"
    local fixture="$2"
    local query="$3"
    local message="$4"
    local actual expected

    actual=$(json_value "$generated" "$query")
    expected=$(json_value "$fixture" "$query")
    [[ "$actual" == "$expected" ]] || fail "$message (expected: $expected, actual: $actual)"
    pass "$message"
}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

run_go test ./...
pass "go test ./..."

reality_json="$tmp_dir/vless-reality.json"
run_xray gen --format xray vless-reality >"$reality_json"
jq . "$reality_json" >/dev/null
pass "generated reality xray json parses"
compare_fixture_value "$reality_json" "$REPO_ROOT/tests/fixtures/xray-conf/vless-reality.json" '.inbounds[0].protocol' "reality protocol matches fixture"
compare_fixture_value "$reality_json" "$REPO_ROOT/tests/fixtures/xray-conf/vless-reality.json" '.inbounds[0].streamSettings.security' "reality security matches fixture"
compare_fixture_value "$reality_json" "$REPO_ROOT/tests/fixtures/xray-conf/vless-reality.json" '.inbounds[0].settings.clients[0].flow' "reality flow matches fixture"
compare_fixture_value "$reality_json" "$REPO_ROOT/tests/fixtures/xray-conf/vless-reality.json" '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "reality serverName matches fixture"

xhttp_json="$tmp_dir/vless-xhttp.json"
run_xray gen --format xray vless-xhttp-tls >"$xhttp_json"
jq . "$xhttp_json" >/dev/null
pass "generated xhttp xray json parses"
compare_fixture_value "$xhttp_json" "$REPO_ROOT/tests/fixtures/xray-conf/vless-xhttp-tls.json" '.inbounds[0].streamSettings.network' "xhttp network matches fixture"
compare_fixture_value "$xhttp_json" "$REPO_ROOT/tests/fixtures/xray-conf/vless-xhttp-tls.json" '.inbounds[0].streamSettings.xhttpSettings.mode' "xhttp mode matches fixture"
compare_fixture_value "$xhttp_json" "$REPO_ROOT/tests/fixtures/xray-conf/vless-xhttp-tls.json" '.inbounds[0].streamSettings.xhttpSettings.path' "xhttp path matches fixture"

ss_client_json="$tmp_dir/shadowsocks-client.json"
run_xray gen --format client shadowsocks >"$ss_client_json"
jq . "$ss_client_json" >/dev/null
[[ "$(json_value "$ss_client_json" '.outbounds[0].settings.servers[0].address')" == "203.0.113.10" ]] || fail "shadowsocks client address"
[[ "$(json_value "$ss_client_json" '.outbounds[0].settings.servers[0].method')" == "aes-256-gcm" ]] || fail "shadowsocks client method"
[[ "$(json_value "$ss_client_json" '.outbounds[0].settings.servers[0].password')" == "example-password" ]] || fail "shadowsocks client password"
pass "generated shadowsocks client json"

mihomo_output=$(run_xray gen --format mihomo)
[[ "$mihomo_output" == *"reality-opts:"* ]] || fail "mihomo reality opts"
[[ "$mihomo_output" == *"network: xhttp"* ]] || fail "mihomo xhttp network"
[[ "$mihomo_output" == *"type: ss"* ]] || fail "mihomo shadowsocks node"
[[ "$mihomo_output" == *"type: socks5"* ]] || fail "mihomo socks node"
[[ "$mihomo_output" == *"skip \"Trojan-XHTTP-TLS-example.com\""* ]] || fail "mihomo unsupported skip"
[[ "$mihomo_output" == *"proxy-groups:"* ]] || fail "mihomo proxy groups"
pass "generated mihomo document"

if run_xray gen --format mihomo trojan-xhttp-tls >"$tmp_dir/trojan-mihomo.out" 2>"$tmp_dir/trojan-mihomo.err"; then
    fail "trojan xhttp mihomo should be unsupported"
fi
grep -q 'mihomo trojan transport supports ws/grpc/tcp only' "$tmp_dir/trojan-mihomo.err" || fail "trojan xhttp unsupported reason"
pass "trojan xhttp mihomo unsupported is explicit"

for go_file in internal/app/app.go internal/protocol/profile.go internal/protocol/xray_json.go internal/protocol/client_json.go internal/protocol/mihomo.go; do
    assert_not_contains "$go_file" 'os\.WriteFile|os\.Mkdir|os\.MkdirAll|os\.Remove|os\.RemoveAll|os\.Rename|exec\.Command|http\.Get' "readonly generation code: $go_file"
done
