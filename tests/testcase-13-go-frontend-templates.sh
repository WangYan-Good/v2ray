#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 3 Go frontend templates"

assert_file "docs/10-project-management/phase-3-frontend-template-plan.md"
assert_file "docs/04-backend/frontend-template-design.md"

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

run_xray() {
    run_go run ./cmd/xray "$@"
}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

run_go test ./...
pass "go test ./..."

nginx_site=$(run_xray gen --format nginx vless-ws-tls)
[[ "$nginx_site" == *"location /.well-known/acme-challenge/"* ]] || fail "nginx site has webroot challenge"
[[ "$nginx_site" == *"root /var/www/certbot;"* ]] || fail "nginx site uses certbot webroot"
[[ "$nginx_site" == *"location /xray-test"* ]] || fail "nginx site has ws location"
[[ "$nginx_site" == *"proxy_pass http://127.0.0.1:10002;"* ]] || fail "nginx site routes ws upstream"
[[ "$nginx_site" == *"proxy_set_header Upgrade \$http_upgrade;"* ]] || fail "nginx site has websocket upgrade"
[[ "$nginx_site" == *"include /etc/nginx/xray/example.com.conf.add;"* ]] || fail "nginx site includes add file"
pass "generated nginx full site"

nginx_grpc_add=$(run_xray gen --format nginx-add vless-grpc-tls)
[[ "$nginx_grpc_add" == *"location /xray-grpc/"* ]] || fail "nginx grpc add has path"
[[ "$nginx_grpc_add" == *"grpc_pass grpc://127.0.0.1:10003;"* ]] || fail "nginx grpc add has upstream"
pass "generated nginx grpc add"

caddy_site=$(run_xray gen --format caddy vless-xhttp-tls)
[[ "$caddy_site" == *"example.com {"* ]] || fail "caddy site has domain"
[[ "$caddy_site" == *"encode gzip"* ]] || fail "caddy site enables gzip"
[[ "$caddy_site" == *"reverse_proxy /xray-test 127.0.0.1:10004"* ]] || fail "caddy site routes xhttp upstream"
[[ "$caddy_site" == *"import /etc/caddy/WangYan-Good/example.com.conf.add"* ]] || fail "caddy site imports add file"
pass "generated caddy full site"

caddy_trojan_add=$(run_xray gen --format caddy-add trojan-xhttp-tls)
[[ "$caddy_trojan_add" == *"reverse_proxy /xray-test 127.0.0.1:10005"* ]] || fail "caddy trojan xhttp add has upstream"
pass "generated caddy trojan xhttp add"

if run_xray gen --format nginx vless-reality >"$tmp_dir/nginx-reality.out" 2>"$tmp_dir/nginx-reality.err"; then
    fail "reality should not render nginx frontend"
fi
grep -q 'no TLS frontend host' "$tmp_dir/nginx-reality.err" || fail "reality unsupported frontend reason"
pass "direct protocols reject frontend template"

assert_not_contains "internal/frontend/nginx/render.go" 'os\.WriteFile|os\.Mkdir|os\.MkdirAll|os\.Remove|os\.RemoveAll|os\.Rename|exec\.Command|http\.Get' "nginx render remains side-effect free"
assert_not_contains "internal/frontend/nginx/inspect.go" 'os\.WriteFile|os\.Mkdir|os\.MkdirAll|os\.Remove|os\.RemoveAll|os\.Rename|exec\.Command|http\.Get' "nginx inspect remains side-effect free"
assert_not_contains "internal/frontend/nginx/certbot.go" 'os\.WriteFile|os\.Mkdir|os\.MkdirAll|os\.Remove|os\.RemoveAll|os\.Rename|exec\.Command|http\.Get' "nginx certbot model remains side-effect free"
assert_not_contains "internal/frontend/caddy/render.go" 'os\.WriteFile|os\.Mkdir|os\.MkdirAll|os\.Remove|os\.RemoveAll|os\.Rename|exec\.Command|http\.Get' "caddy render remains side-effect free"
assert_not_contains "internal/frontend/caddy/inspect.go" 'os\.WriteFile|os\.Mkdir|os\.MkdirAll|os\.Remove|os\.RemoveAll|os\.Rename|exec\.Command|http\.Get' "caddy inspect remains side-effect free"
