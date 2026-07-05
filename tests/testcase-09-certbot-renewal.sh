#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking Phase 0 Certbot renewal contracts"

assert_file "tests/fixtures/certbot/renewal-webroot.conf"
assert_file "tests/fixtures/certbot/renewal-standalone.conf"

assert_contains "tests/fixtures/certbot/renewal-webroot.conf" 'authenticator = webroot' "webroot renewal fixture is recognized"
assert_contains "tests/fixtures/certbot/renewal-webroot.conf" 'webroot_path = /var/www/certbot,' "webroot renewal fixture has webroot path"
assert_contains "tests/fixtures/certbot/renewal-webroot.conf" 'example\.com = /var/www/certbot' "webroot renewal fixture has webroot map"
assert_contains "tests/fixtures/certbot/renewal-standalone.conf" 'authenticator = standalone' "standalone renewal fixture is recognized"
assert_not_contains "tests/fixtures/certbot/renewal-standalone.conf" 'webroot_path = /var/www/certbot' "standalone renewal fixture lacks webroot path"

assert_contains "src/nginx.sh" 'nginx_certbot_renewal_file' "nginx has renewal file helper"
assert_contains "src/nginx.sh" 'nginx_certbot_renewal_authenticator' "nginx has renewal authenticator helper"
assert_contains "src/nginx.sh" 'nginx_certbot_ensure_webroot_renewal' "nginx ensures webroot renewal"
assert_contains "src/nginx.sh" 'authenticator = standalone' "nginx detects standalone renewal"
assert_contains "src/nginx.sh" 'authenticator = webroot' "nginx writes webroot renewal"
assert_contains "src/nginx.sh" 'webroot_path = /var/www/certbot,' "nginx writes webroot path"
assert_contains "src/nginx.sh" 'certbot certonly --webroot' "nginx issue path uses webroot"
assert_not_contains "src/nginx.sh" 'certbot certonly --standalone' "nginx default issue path does not use standalone"
assert_not_contains "src/nginx.sh" 'systemctl stop nginx' "nginx certbot flow does not stop nginx"
