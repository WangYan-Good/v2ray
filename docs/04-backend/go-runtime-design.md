# Go Runtime Design

## Runtime Model

`/usr/local/bin/xray` is the Go CLI and the production command dispatcher. Shell is retained for `install.sh` bootstrap and shell-based tests.

The Go CLI owns:

- Xray config store under `/etc/xray/config.json` and `/etc/xray/conf`.
- Protocol JSON, share URL, full client JSON and Mihomo YAML generation.
- Nginx/Caddy route rendering and Certbot webroot renewal planning.
- Service commands through `systemctl` and Xray-core passthrough through `/etc/xray/bin/xray`.
- Install/update/uninstall file layout and release asset selection.

## Install Flow

Remote one-line install remains:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/WangYan-Good/xray/main/install.sh)
```

`install.sh` downloads `xray-linux-{amd64,arm64}.tar.gz`, verifies `checksums.txt`, installs `/usr/local/bin/xray`, then runs `xray install`.

## Removed Historical Runtime

The following are no longer production assets:

- `code.zip`
- `xray.sh`
- `src/`
- `/etc/xray/sh`
- `internal/legacy`

Historical Phase 5/6 documents remain as migration history only.
