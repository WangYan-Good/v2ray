#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 5 Go legacy switch"

assert_file "docs/10-project-management/phase-5-command-switch-plan.md"
assert_file "docs/04-backend/legacy-compatibility-design.md"

tmp_dir="$REPO_ROOT/.tmp-testcase-15"
legacy_host="$tmp_dir/xray-legacy.sh"
legacy_container="/workspace/.tmp-testcase-15/xray-legacy.sh"
mkdir -p "$tmp_dir"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$legacy_host" <<'LEGACY'
#!/usr/bin/env bash
printf 'legacy:%s\n' "$*"
if [[ "${2:-}" == "fail" ]]; then
    exit 9
fi
exit 0
LEGACY
chmod +x "$legacy_host"

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

run_xray_with_legacy() {
    if command -v go >/dev/null 2>&1; then
        XRAY_LEGACY_BIN="$legacy_host" go run ./cmd/xray "$@"
        return
    fi

    if command -v docker >/dev/null 2>&1; then
        local image="${GO_CONTAINER_IMAGE:-docker.m.daocloud.io/library/golang:1.22}"
        docker run --rm \
            -e "XRAY_LEGACY_BIN=$legacy_container" \
            -v "$REPO_ROOT:/workspace" \
            -w /workspace \
            "$image" \
            go run ./cmd/xray "$@"
        return
    fi

    fail "Go toolchain unavailable: install go or provide docker/podman with golang:1.22"
}

run_xray() {
    run_go run ./cmd/xray "$@"
}

run_go test ./...
pass "go test ./..."

legacy_output=$(run_xray_with_legacy add vws example.com 2>"$tmp_dir/legacy.err")
[[ "$legacy_output" == *"legacy:add vws example.com"* ]] || fail "legacy receives delegated args"
grep -q 'delegating legacy command "add"' "$tmp_dir/legacy.err" || fail "legacy delegation warning"
pass "legacy command delegates to Bash"

set +e
run_xray_with_legacy add fail >"$tmp_dir/legacy-fail.out" 2>"$tmp_dir/legacy-fail.err"
legacy_code=$?
set -e
[[ "$legacy_code" != "0" ]] || fail "legacy failure should be non-zero"
grep -Eq 'exit status 9|delegating legacy command "add"' "$tmp_dir/legacy-fail.err" || fail "legacy failure is visible"
pass "legacy failure is visible through go run"

set +e
run_xray_with_legacy definitely-missing >"$tmp_dir/unknown.out" 2>"$tmp_dir/unknown.err"
unknown_code=$?
set -e
[[ "$unknown_code" != "0" ]] || fail "unknown command should be non-zero"
grep -q 'unknown command: definitely-missing' "$tmp_dir/unknown.err" || fail "unknown command is explicit"
if grep -q 'legacy:' "$tmp_dir/unknown.out"; then
    fail "unknown command should not delegate"
fi
pass "unknown command is not delegated"

switch_plan=$(run_xray switch-plan)
[[ "$switch_plan" == *"entry = /usr/local/bin/xray"* ]] || fail "switch plan entry"
[[ "$switch_plan" == *"legacy = /etc/xray/sh/xray.sh"* ]] || fail "switch plan legacy"
[[ "$switch_plan" == *"rollback = ln -sf /etc/xray/sh/xray.sh /usr/local/bin/xray"* ]] || fail "switch plan rollback"
pass "switch-plan documents Go entry and rollback"

assert_contains "install.sh" 'go_asset="xray-linux-\$\{is_go_arch\}\.tar\.gz"' "install downloads Go CLI asset"
assert_contains "install.sh" 'releases/latest/download/checksums\.txt' "install verifies Go CLI checksums"
assert_contains "install.sh" 'cp -f "\$tmpdir/go-cli/\$is_core" "\$is_sh_bin"' "install writes Go CLI to /usr/local/bin/xray"
assert_contains "install.sh" '已保留 Bash 兼容入口' "install keeps Bash legacy entry"
assert_contains "install.sh" 'ln -sf "\$is_sh_dir/\$is_core\.sh" "\$is_sh_bin"' "install has Bash rollback fallback"
