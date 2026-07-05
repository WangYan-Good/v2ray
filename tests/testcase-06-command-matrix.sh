#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 0 command matrix contracts"

assert_file "docs/04-backend/command-matrix.md"
assert_file "docs/07-data/protocol-contracts.md"

for command in version status info url gen add change del mihomo refresh-sub sub-url update uninstall; do
    assert_contains "docs/04-backend/command-matrix.md" "\`$command\`" "command matrix documents $command"
done

for route in 'gen \| i \| info \| url \| s \| status \| v \| ver \| version' 'qr\)' 'mihomo \| clash' 'refresh-sub \| sub-refresh' 'sub-url' 'u \| up \| update \| U \| update\.sh'; do
    assert_contains "src/core.sh" "$route" "main route exists: $route"
done

for alias in 'r \| reality' 'vxhttp \| txhttp' 'ws \| h2 \| grpc' 'vws \| vh2 \| vgrpc' 'tws \| th2 \| tgrpc' 'ss' 'socks'; do
    assert_contains "src/core.sh" "$alias" "add alias exists: $alias"
done

for protocol in VLESS-XTLS-uTLS-REALITY VLESS-WS-TLS VLESS-gRPC-TLS VLESS-XHTTP-TLS Trojan-XHTTP-TLS VMess-TCP Shadowsocks Socks; do
    assert_contains "docs/07-data/protocol-contracts.md" "$protocol" "protocol contract documents $protocol"
done
