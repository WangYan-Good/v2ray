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

for alias in 'r \| reality' 'vxhttp\)' 'txhttp\)' 'ws \| h2 \| grpc' 'vws \| vh2 \| vgrpc' 'tws \| th2 \| tgrpc' 'ss' 'socks'; do
    assert_contains "src/core.sh" "$alias" "add alias exists: $alias"
done

assert_contains "src/core.sh" 'is_new_protocol=VLESS-XHTTP-TLS' "vxhttp maps to VLESS-XHTTP-TLS"
assert_contains "src/core.sh" 'is_new_protocol=Trojan-XHTTP-TLS' "txhttp maps to Trojan-XHTTP-TLS"
assert_contains "src/core.sh" '\*reality\*\)' "full REALITY protocol uses reality arg parser"
assert_contains "src/core.sh" 'trojan_password=\$is_use_pass' "trojan xhttp password bypasses uuid validation"

xhttp_line=$(grep -n '^[[:space:]]*\*-xhttp-tls)' src/core.sh | head -1 | cut -d: -f1)
tls_line=$(grep -n '^[[:space:]]*\*-tls)' src/core.sh | head -1 | cut -d: -f1)
[[ -n "$xhttp_line" && -n "$tls_line" && "$xhttp_line" -lt "$tls_line" ]] || fail "xhttp args must be parsed before generic tls"
pass "xhttp args are parsed before generic tls"

for protocol in VLESS-XTLS-uTLS-REALITY VLESS-WS-TLS VLESS-gRPC-TLS VLESS-XHTTP-TLS Trojan-XHTTP-TLS VMess-TCP Shadowsocks Socks; do
    assert_contains "docs/07-data/protocol-contracts.md" "$protocol" "protocol contract documents $protocol"
done
