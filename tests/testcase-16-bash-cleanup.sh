#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 6 Bash cleanup"

assert_file "docs/10-project-management/phase-6-bash-cleanup-plan.md"
assert_file "docs/04-backend/bash-cleanup-design.md"

assert_contains "internal/legacy/commands.go" '"version":' "legacy classifier marks version as migrated"
assert_contains "internal/legacy/commands.go" '"status":' "legacy classifier marks status as migrated"
assert_contains "internal/legacy/commands.go" '"info":' "legacy classifier marks info as migrated"
assert_contains "internal/legacy/commands.go" '"url":' "legacy classifier marks url as migrated"
assert_contains "internal/legacy/commands.go" '"gen":' "legacy classifier marks gen as migrated"
assert_contains "internal/legacy/commands.go" '"download-plan":' "legacy classifier marks download-plan as migrated"
assert_contains "internal/legacy/commands.go" '"switch-plan":' "legacy classifier marks switch-plan as migrated"

assert_contains "src/core.sh" 'migrated_to_go\(\)' "bash has migrated command helper"
assert_contains "src/core.sh" 'gen \| i \| info \| url \| s \| status \| v \| ver \| version \| download-plan \| switch-plan' "bash migrated commands share Go notice route"
assert_contains "src/core.sh" '命令 \(\$\{command\}\) 已迁移到 Go CLI' "bash migrated route points to Go CLI"
assert_not_contains "src/core.sh" '\[\[ \$1 == '\''gen'\'' \]\] && is_gen=1' "bash gen no longer enters add generator"
assert_not_contains "src/core.sh" 'url \| qr\)' "bash url no longer shares qr route"

for route in 'a \| add \| no-auto-tls' 'c \| config \| change' 'd \| del \| rm' 'u \| up \| update \| U \| update\.sh' 'mihomo \| clash' 'refresh-sub \| sub-refresh' 'sub-url' 'fix-config\.json' 'fix-caddyfile' 'fix-nginxfile'; do
    assert_contains "src/core.sh" "$route" "bash legacy route remains: $route"
done

assert_contains ".github/workflows/release.yml" 'code\.zip' "release keeps Bash code.zip"
assert_contains ".github/workflows/release.yml" 'install\.sh' "release keeps install.sh"
assert_contains ".github/workflows/release.yml" 'xray-linux-amd64\.tar\.gz' "release keeps Go amd64 asset"
assert_contains ".github/workflows/release.yml" 'xray-linux-arm64\.tar\.gz' "release keeps Go arm64 asset"
