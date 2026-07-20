# Xray Go CLI

Xray installation and management CLI implemented in Go.

The production runtime is `/usr/local/bin/xray`, built from `cmd/xray`. `install.sh` is retained as a remote bootstrap that downloads and verifies the Go release asset, then runs `xray install`.

## Install

```bash
bash <(curl -Ls https://raw.githubusercontent.com/WangYan-Good/xray/main/install.sh)
```

Options:

```bash
bash install.sh --tls nginx --acme-email user@example.com
bash install.sh --tls nginx --acme-no-email # explicit opt-in only
bash install.sh --tls caddy
bash install.sh --proxy http://127.0.0.1:7890
bash install.sh --version v2.0.0-release
bash install.sh --core-version v26.3.27
```

For Nginx, point the domain to the VPS and open TCP 80/443 before adding the
first TLS node. The installer prepares Nginx, Certbot, the webroot and services;
the first TLS `add` keeps Nginx online, obtains the certificate with the webroot
challenge, validates the final configuration and then reloads Nginx.

## Common Commands

```bash
xray version
xray status
xray add vws example.com
xray add vxhttp 10004 11111111-1111-4111-8111-111111111111 example.com /xray-test
xray add reality 10001 11111111-1111-4111-8111-111111111111 www.microsoft.com
xray info vless
xray url vless
xray client vless > client.json
xray mihomo
xray refresh-sub example.com
xray sub-url example.com
xray del vless
xray test
xray test nginx
xray test certbot
xray test all
xray fix-nginxfile
xray restart
```

## Nginx and Certbot

The request path is `client -> Nginx :443 -> 127.0.0.1:<Xray port>`. Certificates
are read directly from `/etc/letsencrypt/live/<domain>/`. Renewal uses the
Certbot timer or cron together with the persistent deploy hook
`/etc/letsencrypt/renewal-hooks/deploy/xray-nginx-reload`, which runs `nginx -t`
before reload.

`xray --dry-run add ...` prints command and file actions without changing the
host. `xray fix-nginxfile` repairs the managed include, old Certbot redirect and
renewal settings, and safely migrates verified `/etc/nginx/ssl` references
before validating and reloading Nginx.

Troubleshooting commands:

```bash
nginx -t
certbot renew --dry-run
systemctl status nginx
systemctl status xray
journalctl -u nginx -n 100
journalctl -u xray -n 100
```

Certificate issuance requires working public DNS and inbound TCP 80. If 80 or
443 is owned by a process other than Nginx, the CLI reports the listener and
does not stop it automatically.

## Release Assets

GitHub Release publishes:

- `install.sh`
- `xray-linux-amd64.tar.gz`
- `xray-linux-arm64.tar.gz`
- `checksums.txt`

`code.zip` is no longer published.

## Development

Use a local Go toolchain or the Go container used by the test harness:

```bash
go test ./...
bash tests/run.sh
bash tests/shellcheck.sh
```

If `go` is unavailable locally, tests use Docker/Podman with `GO_CONTAINER_IMAGE` defaulting to `docker.m.daocloud.io/library/golang:1.22`.

## Documentation

Canonical docs live under `docs/`:

- `docs/10-project-management/go-refactor-plan.md`
- `docs/10-project-management/phase-7-production-cutover-plan.md`
- `docs/04-backend/go-runtime-design.md`
- `docs/04-backend/command-matrix.md`
- `docs/09-testing/test-strategy.md`
