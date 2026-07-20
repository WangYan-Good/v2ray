#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking transactional Nginx and Certbot deployment contracts"

assert_contains "install.sh" '--acme-email' "remote installer accepts ACME email"
assert_contains "install.sh" '--acme-no-email' "remote installer supports explicit no-email mode"
assert_contains "internal/frontend/nginx/render.go" '/etc/letsencrypt/live' "final site uses Certbot live directory"
assert_contains "internal/frontend/nginx/render.go" 'return 503' "bootstrap does not redirect to unavailable HTTPS"
assert_contains "internal/frontend/nginx/deploy.go" 'CertbotIssueCommand' "deployer issues certificates through the command model"
assert_contains "internal/frontend/nginx/deploy.go" 'CertbotRenewDryRunCommand' "new certificate flow verifies renewal"
assert_contains "internal/frontend/nginx/certbot.go" 'xray-nginx-reload' "persistent deploy hook is defined"
assert_contains "internal/frontend/nginx/certbot.go" 'nginx -t' "deploy hook validates before reload"
assert_contains "internal/system/real_runner.go" 'exec\.CommandContext' "real command execution is centralized"
assert_not_contains "internal/app/commands.go" '(^|[^[:alnum:]_])exec\.Command(Context)?\(' "app layer does not execute host commands directly"
assert_not_contains "internal/frontend/nginx/plan.go" 'certonly", "--standalone|stop", "nginx"' "certificate issue never stops Nginx or uses standalone"
assert_not_contains "internal/frontend/nginx/plan.go" '--deploy-hook' "renew dry-run relies on persistent hook"

pass "transactional Nginx/Certbot contracts"
