#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking protocol coverage contracts"

protocols=(
    "VLESS-XTLS-uTLS-REALITY"
    "VLESS-XHTTP-TLS"
    "Trojan-XHTTP-TLS"
    "VMess-WS-TLS"
    "VLESS-WS-TLS"
    "Trojan-WS-TLS"
    "Shadowsocks"
    "VMess-TCP"
)

for protocol in "${protocols[@]}"; do
    assert_contains "src/core.sh" "$protocol" "protocol present: $protocol"
done
