#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 1 Go readonly CLI"

assert_file "go.mod"
assert_file "cmd/xray/main.go"

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
    run_go run ./cmd/xray --conf-dir tests/fixtures/xray-conf "$@"
}

run_go test ./...
pass "go test ./..."

version_output=$(run_xray version)
[[ "$version_output" == *"xray go-cli dev"* ]] || fail "go version command output"
pass "go readonly version command"

status_output=$(run_xray status)
[[ "$status_output" == *"node_count = 8"* ]] || fail "go status reports fixture node count"
pass "go readonly status command"

reality_info=$(run_xray info vless-reality)
[[ "$reality_info" == *"protocol = vless"* ]] || fail "reality info protocol"
[[ "$reality_info" == *"security = reality"* ]] || fail "reality info security"
[[ "$reality_info" == *"serverName = www.microsoft.com"* ]] || fail "reality info serverName"
[[ "$reality_info" == *"publicKey = example-public-key"* ]] || fail "reality info publicKey"
pass "go readonly info reality"

ws_info=$(run_xray info vless-ws)
[[ "$ws_info" == *"network = ws"* ]] || fail "ws info network"
[[ "$ws_info" == *"host = example.com"* ]] || fail "ws info host"
[[ "$ws_info" == *"path = /xray-test"* ]] || fail "ws info path"
pass "go readonly info ws"

grpc_info=$(run_xray info vless-grpc)
[[ "$grpc_info" == *"network = grpc"* ]] || fail "grpc info network"
[[ "$grpc_info" == *"serviceName = xray-grpc"* ]] || fail "grpc info serviceName"
pass "go readonly info grpc"

xhttp_url=$(run_xray url vless-xhttp)
[[ "$xhttp_url" == vless://* ]] || fail "xhttp url scheme"
[[ "$xhttp_url" == *"security=tls"* ]] || fail "xhttp url security"
[[ "$xhttp_url" == *"type=xhttp"* ]] || fail "xhttp url type"
[[ "$xhttp_url" == *"path=%2Fxray-test"* ]] || fail "xhttp url path"
pass "go readonly url xhttp"

ss_url=$(run_xray url shadowsocks)
[[ "$ss_url" == ss://aes-256-gcm:example-password@203.0.113.10:10007* ]] || fail "shadowsocks url"
pass "go readonly url shadowsocks"

socks_url=$(run_xray url socks)
[[ "$socks_url" == socks://* ]] || fail "socks url scheme"
[[ "$socks_url" == *"@203.0.113.10:10008"* ]] || fail "socks url address"
pass "go readonly url socks"

assert_not_contains "internal/app/app.go" 'os\.WriteFile|os\.Mkdir|os\.MkdirAll|os\.Remove|os\.RemoveAll|os\.Rename|exec\.Command|http\.Get' "go app package remains readonly"
assert_not_contains "internal/config/reader.go" 'os\.WriteFile|os\.Mkdir|os\.MkdirAll|os\.Remove|os\.RemoveAll|os\.Rename|exec\.Command|http\.Get' "go config package remains readonly"
