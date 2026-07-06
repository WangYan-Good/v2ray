#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking runtime cleanup"

assert_file "docs/10-project-management/phase-6-bash-cleanup-plan.md"
assert_file "docs/04-backend/bash-cleanup-design.md"

if [[ -e xray.sh || -d src || -d internal/legacy ]]; then
    ls -ld xray.sh src internal/legacy 2>/dev/null || true
    fail "production Bash runtime and legacy delegate must be removed"
fi
pass "production Bash runtime is removed"

assert_not_contains "internal/app/app.go" 'internal/legacy|XRAY_LEGACY_BIN|delegating legacy command|/etc/xray/sh' "app has no legacy delegate"
assert_contains "internal/app/app.go" '"add", "a", "no-auto-tls"' "Go owns add route"
assert_contains "internal/app/app.go" '"change", "config", "c"' "Go owns change route"
assert_contains "internal/app/app.go" '"del", "rm", "d"' "Go owns del route"
assert_contains "internal/app/app.go" '"mihomo", "clash"' "Go owns mihomo route"
assert_contains "internal/app/app.go" '"refresh-sub", "sub-refresh"' "Go owns refresh-sub route"
assert_contains "internal/app/app.go" '"uninstall", "un"' "Go owns uninstall route"

assert_not_contains ".github/workflows/release.yml" 'code\.zip|xray\.sh|src/' "release omits Bash runtime asset"
assert_contains ".github/workflows/release.yml" 'install\.sh' "release keeps remote installer"
assert_contains ".github/workflows/release.yml" 'xray-linux-amd64\.tar\.gz' "release keeps Go amd64 asset"
assert_contains ".github/workflows/release.yml" 'xray-linux-arm64\.tar\.gz' "release keeps Go arm64 asset"
