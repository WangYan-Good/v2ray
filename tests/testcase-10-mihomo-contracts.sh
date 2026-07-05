#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 0 Mihomo contracts"

assert_file "tests/fixtures/mihomo/mihomo.yaml"

assert_yaml_contains "tests/fixtures/mihomo/mihomo.yaml" 'type: vless' "mihomo includes vless nodes"
assert_yaml_contains "tests/fixtures/mihomo/mihomo.yaml" 'reality-opts:' "mihomo includes reality opts"
assert_yaml_contains "tests/fixtures/mihomo/mihomo.yaml" 'public-key: "example-public-key"' "mihomo preserves reality public key"
assert_yaml_contains "tests/fixtures/mihomo/mihomo.yaml" 'network: xhttp' "mihomo includes xhttp network"
assert_yaml_contains "tests/fixtures/mihomo/mihomo.yaml" 'xhttp-opts:' "mihomo includes xhttp opts"
assert_yaml_contains "tests/fixtures/mihomo/mihomo.yaml" 'type: ss' "mihomo includes shadowsocks node"
assert_yaml_contains "tests/fixtures/mihomo/mihomo.yaml" 'type: socks5' "mihomo includes socks node"
assert_yaml_contains "tests/fixtures/mihomo/mihomo.yaml" 'skip "Trojan-XHTTP-TLS-example.com": mihomo trojan transport supports ws/grpc/tcp only' "mihomo documents unsupported trojan xhttp"
assert_yaml_contains "tests/fixtures/mihomo/mihomo.yaml" 'proxy-groups:' "mihomo includes proxy groups"
assert_yaml_contains "tests/fixtures/mihomo/mihomo.yaml" '      - DIRECT' "mihomo includes direct fallback"

assert_contains "src/mihomo.sh" 'chmod 600 "\$is_sub_token_file"' "mihomo token permission is 600"
assert_contains "src/mihomo.sh" 'chmod 644 "\$is_mihomo_sub_file"' "mihomo yaml permission is 644"
assert_contains "src/mihomo.sh" 'mihomo trojan transport supports ws/grpc/tcp only' "mihomo skips trojan xhttp explicitly"
assert_contains "src/mihomo.sh" 'xhttp-opts:' "mihomo emits xhttp opts"
assert_contains "src/mihomo.sh" 'reality-opts:' "mihomo emits reality opts"
