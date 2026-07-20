# Go Runtime Design

## Runtime Model

`/usr/local/bin/xray` is the Go CLI and the production command dispatcher. Shell is retained for `install.sh` bootstrap and shell-based tests.

The Go CLI owns:

- Xray config store under `/etc/xray/config.json` and `/etc/xray/conf`.
- Protocol JSON, share URL, full client JSON and Mihomo YAML generation.
- Nginx/Caddy route rendering and transactional Nginx/Certbot deployment.
- Service commands through `systemctl` and Xray-core passthrough through `/etc/xray/bin/xray`.
- Install/update/uninstall file layout and release asset selection.

## Install Flow

Remote one-line install remains:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/WangYan-Good/xray/main/install.sh)
```

`install.sh` downloads `xray-linux-{amd64,arm64}.tar.gz`, verifies `checksums.txt`, installs `/usr/local/bin/xray`, then runs `xray install`. Nginx mode accepts `--acme-email` or explicit `--acme-no-email` and passes proxy settings to downloads and package management.

The Go installer detects apt, dnf or yum, installs only missing Nginx dependencies,
writes the managed configuration and renewal hook, validates Xray and Nginx, then
runs `systemctl daemon-reload` and enables the required services. Caddy mode does
not install or start Nginx.

## Execution and transactions

Host commands cross `internal/system.Runner`; production captures stdout, stderr
and exit status, while tests use `RecordingRunner`. File changes use root-aware
atomic writes and rollback snapshots. `--dry-run` records commands and file actions
without writing or changing services. Nginx/Certbot failures restore the prior
Xray and Nginx state, and errors report both the original and rollback failures.

## Removed Historical Runtime

The following are no longer production assets:

- `code.zip`
- `xray.sh`
- `src/`
- `/etc/xray/sh`
- `internal/legacy`

Historical Phase 5/6 documents remain as migration history only.
