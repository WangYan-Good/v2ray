#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 0 frontend fixture contracts"

assert_file "tests/fixtures/nginx/single-domain.conf"
assert_file "tests/fixtures/nginx/single-domain.conf.add"
assert_file "tests/fixtures/nginx/multi-protocol-domain.conf"
assert_file "tests/fixtures/nginx/multi-protocol-domain.conf.add"
assert_file "tests/fixtures/caddy/single-domain.conf"
assert_file "tests/fixtures/caddy/single-domain.conf.add"
assert_file "tests/fixtures/caddy/multi-protocol-domain.conf.add"

assert_contains "tests/fixtures/nginx/single-domain.conf" 'include /etc/nginx/xray/example\.com\.conf\.add;' "nginx primary config includes add file"
assert_file_contains_once "tests/fixtures/nginx/multi-protocol-domain.conf" 'location /xray-test' "nginx primary route remains single"
assert_contains "tests/fixtures/nginx/multi-protocol-domain.conf.add" 'location /xray-grpc/' "nginx add file contains grpc route"
assert_contains "tests/fixtures/nginx/multi-protocol-domain.conf.add" 'grpc_pass grpc://127\.0\.0\.1:10003;' "nginx grpc upstream is preserved"
assert_contains "tests/fixtures/nginx/multi-protocol-domain.conf.add" 'location /xray-xhttp' "nginx add file contains xhttp route"
assert_contains "tests/fixtures/nginx/multi-protocol-domain.conf.add" 'proxy_pass http://127\.0\.0\.1:10004;' "nginx xhttp upstream is preserved"
assert_contains "tests/fixtures/nginx/multi-protocol-domain.conf.add" 'location /xray-test' "nginx fixture includes conflict sample"
assert_contains "tests/fixtures/nginx/multi-protocol-domain.conf.add" 'proxy_pass http://127\.0\.0\.1:10999;' "nginx conflict sample uses different port"
assert_file_contains_once "tests/fixtures/nginx/multi-protocol-domain.conf.add" '# xray-mihomo-sub-start' "nginx mihomo route is idempotent block"

assert_contains "tests/fixtures/caddy/single-domain.conf" 'import /etc/caddy/WangYan-Good/example\.com\.conf\.add' "caddy primary config imports add file"
assert_contains "tests/fixtures/caddy/multi-protocol-domain.conf.add" 'reverse_proxy /xray-grpc/\* h2c://127\.0\.0\.1:10003' "caddy add file contains grpc route"
assert_contains "tests/fixtures/caddy/multi-protocol-domain.conf.add" 'reverse_proxy /xray-xhttp 127\.0\.0\.1:10004' "caddy add file contains xhttp route"
assert_contains "tests/fixtures/caddy/multi-protocol-domain.conf.add" 'reverse_proxy /xray-test 127\.0\.0\.1:10999' "caddy fixture includes conflict sample"
assert_file_contains_once "tests/fixtures/caddy/multi-protocol-domain.conf.add" '# xray-mihomo-sub-start' "caddy mihomo route is idempotent block"

assert_contains "internal/frontend/nginx/inspect.go" 'CheckAppend' "nginx append mode helper exists"
assert_contains "internal/frontend/nginx/inspect.go" 'EnsureAddInclude' "nginx include repair helper exists"
assert_contains "internal/frontend/nginx/inspect.go" 'AppendConflict' "nginx path conflict model exists"
