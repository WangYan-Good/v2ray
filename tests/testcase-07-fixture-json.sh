#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 0 Xray JSON fixtures"

for fixture in "$REPO_ROOT"/tests/fixtures/xray-conf/*.json; do
    jq . "$fixture" >/dev/null
    pass "valid json: tests/fixtures/xray-conf/$(basename "$fixture")"
done

assert_json_value "tests/fixtures/xray-conf/vless-reality.json" '.inbounds[0].protocol' "vless" "reality protocol is vless"
assert_json_value "tests/fixtures/xray-conf/vless-reality.json" '.inbounds[0].listen' "0.0.0.0" "reality listens publicly"
assert_json_value "tests/fixtures/xray-conf/vless-reality.json" '.inbounds[0].settings.clients[0].flow' "xtls-rprx-vision" "reality flow is preserved"
assert_json_value "tests/fixtures/xray-conf/vless-reality.json" '.inbounds[0].streamSettings.security' "reality" "reality security is preserved"
assert_json_value "tests/fixtures/xray-conf/vless-reality.json" '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "www.microsoft.com" "reality serverName is preserved"
assert_json_value "tests/fixtures/xray-conf/vless-reality.json" '.inbounds[0].streamSettings.realitySettings.publicKey' "example-public-key" "reality public key is preserved"

assert_json_value "tests/fixtures/xray-conf/vless-ws-tls.json" '.inbounds[0].listen' "127.0.0.1" "ws tls listens locally"
assert_json_value "tests/fixtures/xray-conf/vless-ws-tls.json" '.inbounds[0].streamSettings.network' "ws" "ws network is preserved"
assert_json_value "tests/fixtures/xray-conf/vless-ws-tls.json" '.inbounds[0].streamSettings.wsSettings.headers.Host' "example.com" "ws host is preserved"

assert_json_value "tests/fixtures/xray-conf/vless-grpc-tls.json" '.inbounds[0].streamSettings.network' "grpc" "grpc network is preserved"
assert_json_value "tests/fixtures/xray-conf/vless-grpc-tls.json" '.inbounds[0].streamSettings.grpcSettings.serviceName' "xray-grpc" "grpc serviceName is preserved"

assert_json_value "tests/fixtures/xray-conf/vless-xhttp-tls.json" '.inbounds[0].streamSettings.network' "xhttp" "vless xhttp network is preserved"
assert_json_value "tests/fixtures/xray-conf/vless-xhttp-tls.json" '.inbounds[0].streamSettings.xhttpSettings.mode' "auto" "vless xhttp mode is auto"
assert_json_value "tests/fixtures/xray-conf/trojan-xhttp-tls.json" '.inbounds[0].protocol' "trojan" "trojan xhttp protocol is preserved"
assert_json_value "tests/fixtures/xray-conf/trojan-xhttp-tls.json" '.inbounds[0].streamSettings.xhttpSettings.mode' "auto" "trojan xhttp mode is auto"

assert_json_value "tests/fixtures/xray-conf/vmess-tcp.json" '.inbounds[0].protocol' "vmess" "vmess tcp protocol is preserved"
assert_json_value "tests/fixtures/xray-conf/vmess-tcp.json" '.inbounds[0].listen' "0.0.0.0" "vmess tcp listens publicly"
assert_json_value "tests/fixtures/xray-conf/vmess-tcp.json" '.inbounds[0].streamSettings.tcpSettings.header.type' "none" "vmess tcp header type is none"

assert_json_value "tests/fixtures/xray-conf/shadowsocks.json" '.inbounds[0].settings.method' "aes-256-gcm" "shadowsocks method is preserved"
assert_json_value "tests/fixtures/xray-conf/socks.json" '.inbounds[0].settings.accounts[0].user' "example-user" "socks username is preserved"
