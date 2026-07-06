#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 0 command matrix contracts"

assert_file "docs/04-backend/command-matrix.md"
assert_file "docs/07-data/protocol-contracts.md"

for command in version status info url gen add change del mihomo refresh-sub sub-url update uninstall; do
    assert_contains "docs/04-backend/command-matrix.md" "\`$command\`" "command matrix documents $command"
done

for route in '"gen"' '"qr"' '"mihomo", "clash"' '"refresh-sub", "sub-refresh"' '"sub-url"' '"update", "up", "u", "update.sh", "U", "reinstall"'; do
    assert_contains "internal/app/app.go" "$route" "Go route exists: $route"
done

for alias in '"r", "reality"' '"vxhttp", "txhttp"' '"vws", "vh2", "vgrpc", "ws", "h2", "grpc", "tws", "th2", "tgrpc"' '"ss"' '"socks"'; do
    assert_contains "internal/app/commands.go" "$alias" "Go add alias exists: $alias"
done

assert_contains "internal/app/commands.go" 'name := "VLESS-XHTTP-TLS"' "vxhttp maps to VLESS-XHTTP-TLS"
assert_contains "internal/app/commands.go" 'name = "Trojan-XHTTP-TLS"' "txhttp maps to Trojan-XHTTP-TLS"
assert_contains "internal/app/commands.go" 'case "r", "reality"' "REALITY protocol uses reality arg parser"
assert_contains "internal/app/commands.go" 'password = credential' "trojan xhttp password bypasses uuid validation"
assert_not_contains "internal/app/app.go" 'delegating legacy command|XRAY_LEGACY_BIN|/etc/xray/sh' "Go app has no legacy delegation"

for protocol in VLESS-XTLS-uTLS-REALITY VLESS-WS-TLS VLESS-gRPC-TLS VLESS-XHTTP-TLS Trojan-XHTTP-TLS VMess-TCP Shadowsocks Socks; do
    assert_contains "docs/07-data/protocol-contracts.md" "$protocol" "protocol contract documents $protocol"
done
