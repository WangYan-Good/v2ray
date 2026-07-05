#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 4 Go download and install plans"

assert_file "docs/10-project-management/phase-4-install-download-plan.md"
assert_file "docs/04-backend/download-install-design.md"

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

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

run_go test ./...
pass "go test ./..."

core_plan=$(run_xray download-plan --version v1.8.24 --arch x86_64 --proxy http://127.0.0.1:7890 core)
[[ "$core_plan" == *"asset.0.name = Xray-linux-64.zip"* ]] || fail "core plan x86 asset"
[[ "$core_plan" == *"asset.0.url = https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip"* ]] || fail "core plan x86 url"
[[ "$core_plan" == *"asset.0.checksum_url = https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip.dgst"* ]] || fail "core plan checksum"
[[ "$core_plan" == *"proxy.http_proxy = http://127.0.0.1:7890"* ]] || fail "core plan proxy lower"
[[ "$core_plan" == *"proxy.HTTPS_PROXY = http://127.0.0.1:7890"* ]] || fail "core plan proxy upper"
pass "download-plan core x86"

arm_core_plan=$(run_xray download-plan --version v1.8.24 --arch aarch64 core)
[[ "$arm_core_plan" == *"asset.0.name = Xray-linux-arm64-v8a.zip"* ]] || fail "core plan arm asset"
pass "download-plan core arm"

caddy_plan=$(run_xray download-plan --version v2.8.4 --arch arm64 caddy)
[[ "$caddy_plan" == *"asset.0.name = caddy_2.8.4_linux_arm64.tar.gz"* ]] || fail "caddy plan asset"
[[ "$caddy_plan" == *"asset.0.checksum_url = https://github.com/caddyserver/caddy/releases/download/v2.8.4/caddy_2.8.4_checksums.txt"* ]] || fail "caddy plan checksum"
pass "download-plan caddy"

dat_plan=$(run_xray download-plan --arch x86_64 dat)
[[ "$dat_plan" == *"asset.0.name = geoip.dat"* ]] || fail "dat plan geoip"
[[ "$dat_plan" == *"asset.1.name = geosite.dat"* ]] || fail "dat plan geosite"
[[ "$dat_plan" == *"https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"* ]] || fail "dat plan geoip url"
pass "download-plan dat"

go_plan=$(run_xray download-plan --version v2.0.0-alpha --arch x86_64 go)
[[ "$go_plan" == *"asset.0.name = xray-linux-amd64.tar.gz"* ]] || fail "go cli plan asset"
[[ "$go_plan" == *"asset.0.checksum_url = https://github.com/WangYan-Good/xray/releases/download/v2.0.0-alpha/checksums.txt"* ]] || fail "go cli plan checksum"
[[ "$go_plan" == *"install xray binary to /usr/local/bin/xray after Phase 5 switch"* ]] || fail "go cli plan phase 5 guard"
pass "download-plan go cli"

if run_xray download-plan --arch riscv64 core >"$tmp_dir/unsupported.out" 2>"$tmp_dir/unsupported.err"; then
    fail "unsupported arch should fail"
fi
grep -q 'unsupported architecture: riscv64' "$tmp_dir/unsupported.err" || fail "unsupported arch error"
pass "unsupported arch is explicit"

assert_contains ".github/workflows/release.yml" 'actions/setup-go@v5' "release workflow sets up Go"
assert_contains ".github/workflows/release.yml" 'GOOS=linux GOARCH=amd64 go build' "release workflow builds linux amd64"
assert_contains ".github/workflows/release.yml" 'GOOS=linux GOARCH=arm64 go build' "release workflow builds linux arm64"
assert_contains ".github/workflows/release.yml" 'xray-linux-amd64\.tar\.gz' "release workflow uploads amd64 tarball"
assert_contains ".github/workflows/release.yml" 'xray-linux-arm64\.tar\.gz' "release workflow uploads arm64 tarball"
assert_contains ".github/workflows/release.yml" 'checksums\.txt' "release workflow uploads checksums"
assert_contains ".github/workflows/release.yml" 'code\.zip' "release workflow keeps code.zip"
assert_contains ".github/workflows/release.yml" 'install\.sh' "release workflow keeps install.sh"

assert_not_contains "internal/download/plan.go" 'os\.WriteFile|os\.Mkdir|os\.MkdirAll|os\.Remove|os\.RemoveAll|os\.Rename|exec\.Command|http\.Get' "download plan remains side-effect free"
assert_not_contains "internal/download/checksum.go" 'os\.WriteFile|os\.Mkdir|os\.MkdirAll|os\.Remove|os\.RemoveAll|os\.Rename|exec\.Command|http\.Get' "checksum parser remains side-effect free"
