# Xray Go CLI

Xray installation and management CLI implemented in Go.

The production runtime is `/usr/local/bin/xray`, built from `cmd/xray`. `install.sh` is retained as a remote bootstrap that downloads and verifies the Go release asset, then runs `xray install`.

## Install

```bash
bash <(curl -Ls https://raw.githubusercontent.com/WangYan-Good/xray/main/install.sh)
```

Options:

```bash
bash install.sh --tls nginx
bash install.sh --tls caddy
bash install.sh --proxy http://127.0.0.1:7890
bash install.sh --version v2.0.0-release
bash install.sh --core-version v26.3.27
```

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
xray restart
```

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
