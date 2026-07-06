#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking deployment regression contracts"

assert_contains "internal/app/commands.go" 'asset := "Xray-linux-64\.zip"' "Go installer uses upstream Xray-core asset casing"
assert_contains "install.sh" 'export http_proxy="\$proxy" https_proxy="\$proxy" HTTP_PROXY="\$proxy" HTTPS_PROXY="\$proxy"' "install.sh exports proxy variables for subprocess downloads"
assert_contains "install.sh" '/usr/local/bin/xray "\$\{install_args\[@\]\}"' "install.sh delegates system setup to Go CLI"
assert_contains "internal/app/commands.go" 'writeMainConfig\(opts\)' "Go install creates config.json"
assert_contains "internal/app/commands.go" 'ExecStart=%s run -config %s -confdir %s' "systemd uses Xray run subcommand with confdir"
assert_contains "internal/frontend/nginx/plan.go" 'certonly", "--webroot"' "Nginx certbot issue uses webroot"
assert_contains "internal/frontend/nginx/certbot.go" 'authenticator = webroot' "Go renewal helper writes webroot authenticator"
assert_not_contains "install.sh" 'code\.zip|xray\.sh|/etc/xray/sh' "install.sh does not install Bash runtime"
