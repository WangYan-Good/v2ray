#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Go command switch"

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

tmp_dir=".tmp-testcase-15"
rm -rf "$tmp_dir"
mkdir -p "$tmp_dir"
trap 'rm -rf "$tmp_dir"' EXIT

run_go test ./...
pass "go test ./..."

run_xray --root "$tmp_dir" install --skip-core --tls nginx --acme-email user@example.com >"$tmp_dir/install.out"
add_output=$(run_xray --root "$tmp_dir" add vws example.com 2>"$tmp_dir/add.err")
[[ "$add_output" == *"added = VLESS-WS-TLS-example.com"* ]] || fail "add is handled by Go"
[[ -f "$tmp_dir/etc/xray/conf/VLESS-WS-TLS-example.com.json" ]] || fail "add writes config through Go"
if grep -q 'delegating legacy command' "$tmp_dir/add.err"; then
    fail "Go add must not delegate"
fi
pass "Go add command does not delegate"

switch_plan=$(run_xray switch-plan)
[[ "$switch_plan" == *"entry = /usr/local/bin/xray"* ]] || fail "switch plan entry"
[[ "$switch_plan" == *"runtime = go"* ]] || fail "switch plan runtime"
[[ "$switch_plan" != *"/etc/xray/sh"* ]] || fail "switch plan must not mention Bash legacy path"
pass "switch-plan documents Go entry"

assert_contains "install.sh" 'asset="xray-linux-\$\{go_arch\}\.tar\.gz"' "install downloads Go CLI asset"
assert_contains "install.sh" 'checksums\.txt' "install verifies Go CLI checksums"
assert_contains "install.sh" 'install -m 0755 "\$\{tmpdir\}/xray" /usr/local/bin/xray' "install writes Go CLI to /usr/local/bin/xray"
assert_contains "install.sh" '/usr/local/bin/xray "\$\{install_args\[@\]\}"' "install delegates setup to Go install"
assert_not_contains "install.sh" '/etc/xray/sh|xray\.sh|code\.zip' "install has no Bash runtime fallback"
