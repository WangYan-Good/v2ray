#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking deployment regression contracts"

assert_contains "install.sh" 'core_file_name="Xray-linux-\$\{is_core_arch\}\.zip"' "install.sh uses upstream Xray-core asset casing"
assert_contains "src/download.sh" 'core_file_name="Xray-linux-\$\{is_core_arch\}\.zip"' "src/download.sh uses upstream Xray-core asset casing"
assert_contains "install.sh" 'export http_proxy=\$proxy https_proxy=\$proxy HTTP_PROXY=\$proxy HTTPS_PROXY=\$proxy' "install.sh exports proxy variables for subprocess downloads"
assert_contains "install.sh" 'install_nginx_certbot \|\| exit_and_del_tmpdir' "install.sh installs selected Nginx frontend"
assert_contains "install.sh" 'download caddy \|\| exit_and_del_tmpdir' "install.sh installs selected Caddy frontend"
assert_contains "src/core.sh" 'is_new_install \|\| ! -f \$is_config_json' "core creates config.json when missing after skipped first node"
assert_contains "src/core.sh" 'nginx_reload \|\| return 1' "core propagates Nginx reload failures"
assert_contains "src/init.sh" 'is_core_major=\$\{is_core_major%%\.\*\}' "init parses full Xray major version"
assert_not_contains "src/init.sh" 'grep -o \^\[0-9\]' "init does not truncate multi-digit Xray major versions"
assert_contains "src/systemd.sh" 'ExecStart=\$is_core_bin run -config \$is_config_json -confdir \$is_conf_dir' "systemd uses Xray run subcommand"
assert_contains "src/nginx.sh" '--force-confmiss' "Nginx install restores missing Debian conffiles"
assert_contains "src/nginx.sh" 'Nginx mime\.types 缺失' "Nginx install has mime.types fallback"
assert_contains "src/nginx.sh" 'command -v crontab' "Nginx cron setup tolerates missing crontab"
