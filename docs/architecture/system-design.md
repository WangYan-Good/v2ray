# System Design

## Overview

This project is an Xray installation and management script. It installs Xray Core, manages inbound configuration files, optionally provisions a TLS frontend through Caddy or Nginx, and exposes helper commands for client configuration, URL/QR output, diagnostics, updates, and Mihomo subscription generation.

The runtime model is intentionally file based:

- Xray runs with one main config file plus a config directory.
- Each managed proxy node is represented by one JSON file under `/etc/xray/conf`.
- Caddy or Nginx owns public TLS entrypoints and reverse-proxies selected paths to local Xray inbound ports.
- The shell command `xray` is the single user-facing control plane.

## Goals

- Provide a low-friction Xray install and management workflow.
- Support multiple protocol profiles on the same server.
- Allow multiple TLS-backed nodes to coexist on one domain or across many domains.
- Preserve compatibility with existing user-managed Nginx/Caddy sites where possible.
- Keep operational state transparent and recoverable through files.
- Avoid long-running custom daemons; rely on systemd, Xray, Nginx, Caddy, and static files.

## Non-Goals

- It is not a web dashboard.
- It is not a general-purpose subscription converter.
- It does not run a custom HTTP API server for subscription generation.
- It does not replace Xray Core protocol validation.

## Runtime Layout

```text
/etc/xray/
|-- bin/
|   |-- xray
|   |-- geoip.dat
|   `-- geosite.dat
|-- sh/
|   |-- xray.sh
|   `-- src/
|       |-- init.sh
|       |-- core.sh
|       |-- caddy.sh
|       |-- nginx.sh
|       |-- mihomo.sh
|       |-- systemd.sh
|       |-- download.sh
|       |-- help.sh
|       |-- log.sh
|       |-- dns.sh
|       `-- bbr.sh
|-- conf/
|   |-- VMess-WS-example.com.json
|   `-- VLESS-gRPC-example.com.json
|-- sub/
|   |-- mihomo.yaml
|   `-- token
`-- config.json
```

Nginx mode:

```text
/etc/nginx/
|-- nginx.conf
|-- ssl/
|   `-- example.com/
|-- xray/
|   |-- example.com.conf
|   `-- example.com.conf.add
`-- sites-enabled/
```

Caddy mode:

```text
/etc/caddy/
|-- Caddyfile
|-- WangYan-Good/
|   |-- example.com.conf
|   `-- example.com.conf.add
`-- sites/
```

## Main Components

| Component | File | Responsibility |
|---|---|---|
| Entrypoint | `xray.sh` | Loads `init.sh` and dispatches command arguments. |
| Bootstrap | `src/init.sh` | Defines paths, detects architecture, loads status, detects Caddy/Nginx, loads `core.sh`. |
| Core command router | `src/core.sh` | Implements `add`, `change`, `del`, `info`, `url`, `qr`, `client`, update, service control, and dispatches feature modules. |
| Xray config builder | `src/core.sh` | Builds Xray inbound JSON files and the main `/etc/xray/config.json`. |
| Caddy integration | `src/caddy.sh` | Creates Caddyfile imports and reverse proxy blocks for WS, gRPC, H2/XHTTP, and fallback sites. |
| Nginx integration | `src/nginx.sh` | Creates Nginx server/location blocks, obtains certificates with Certbot, validates and reloads Nginx. |
| Mihomo subscription | `src/mihomo.sh` | Generates static Mihomo YAML, token, subscription URL, and web-server route snippets. |
| Downloads | `src/download.sh` | Downloads Xray Core, data files, Caddy, Nginx, and dependency assets. |
| Service units | `src/systemd.sh` | Writes systemd service definitions for Xray and Caddy. |
| Operations helpers | `src/log.sh`, `src/dns.sh`, `src/bbr.sh` | Logging, DNS setup, and BBR helpers. |

## Command Flow

```text
user
  |
  v
/usr/local/bin/xray
  |
  v
/etc/xray/sh/xray.sh
  |
  v
src/init.sh
  |
  v
src/core.sh main "$@"
  |
  +-- add/change/del/info/url/qr/client
  +-- start/stop/restart/status
  +-- update/reinstall/uninstall
  +-- fix/fix-all/fix-nginxfile/fix-caddyfile
  +-- mihomo/refresh-sub/sub-url
```

## Configuration Model

The script treats `/etc/xray/conf/*.json` as the source of managed node state. Each file contains a single Xray inbound. The main `/etc/xray/config.json` contains shared service-level settings:

- logging
- DNS
- API and stats
- routing
- base outbound definitions

Xray is started with:

```text
xray run -config /etc/xray/config.json -confdir /etc/xray/conf
```

For new nodes, `core.sh`:

1. Parses the requested protocol profile.
2. Resolves or asks for host, port, UUID, path, password, and transport-specific fields.
3. Builds inbound JSON through `jq`.
4. Writes the per-node JSON file.
5. Adds it to the running Xray process through the Xray API when possible.
6. Generates or updates Caddy/Nginx frontend configuration when TLS mode is enabled.
7. Refreshes the static Mihomo subscription file.

## TLS Frontend Model

TLS-backed transports usually listen on `127.0.0.1` inside Xray. Caddy or Nginx terminates public TLS and proxies traffic to the local inbound port.

Typical WS flow:

```text
client
  |
  | TLS + WebSocket /path
  v
Caddy/Nginx :443
  |
  | reverse_proxy /path
  v
Xray inbound 127.0.0.1:random_port
```

Non-TLS TCP, mKCP, QUIC, Shadowsocks, Socks, and Reality profiles bind directly as Xray inbounds and do not require Caddy/Nginx reverse proxying.

## Multi-Site and Multi-Protocol Design

For one domain with multiple Xray transports, the project uses a split file model:

- `domain.conf` contains the main TLS server block.
- `domain.conf.add` contains appended routes such as extra `location` or `reverse_proxy` blocks.

This keeps generated Xray routes separate from user-managed site content and allows multiple protocol paths to coexist under the same domain.

For Nginx, the project also preserves `/etc/nginx/sites-enabled` for non-Xray sites.

## Mihomo Subscription Design

Mihomo support is implemented as static YAML generation rather than request-time shell execution.

Commands:

```bash
xray mihomo [name]
xray refresh-sub [domain]
xray sub-url [domain]
```

Files:

```text
/etc/xray/sub/mihomo.yaml
/etc/xray/sub/token
```

Flow:

```text
add/change/del/fix-all
  |
  v
src/mihomo.sh
  |
  v
generate /etc/xray/sub/mihomo.yaml

xray refresh-sub example.com
  |
  +-- refresh YAML
  +-- create token if missing
  +-- append /sub/mihomo route to Caddy or Nginx
  +-- print https://example.com/sub/mihomo?token=...
```

The HTTP server only serves a static file and checks a token in the generated route. It does not execute shell commands on request.

## Protocol Profile Model

The project exposes protocol profiles through `protocol_list` in `src/core.sh`.

Current profile families:

- VMess: TCP, mKCP, QUIC, H2/XHTTP, WS, gRPC, dynamic-port variants.
- VLESS: H2/XHTTP, WS, gRPC, XTLS-uTLS-REALITY.
- Trojan: H2/XHTTP, WS, gRPC.
- Shadowsocks.
- Socks.

The internal parser maps profile names to:

- `is_protocol`: Xray protocol, such as `vmess`, `vless`, `trojan`, `shadowsocks`, `socks`.
- `net`: transport family, such as `tcp`, `kcp`, `quic`, `ws`, `grpc`, `xhttp`, `reality`, `ss`, `socks`.
- `json_str` / `is_stream`: Xray inbound settings and stream settings.

Mihomo subscription support is a separate compatibility layer. A protocol profile may be valid for Xray but not exportable to Mihomo if Mihomo lacks the same transport semantics.

## State and Side Effects

| Operation | Primary state change | Secondary side effects |
|---|---|---|
| `xray add` | Adds one JSON file under `/etc/xray/conf` | Updates Xray API/runtime, Caddy/Nginx route, Mihomo YAML. |
| `xray change` | Recreates or edits one managed JSON file | May update TLS frontend routes and reload services. |
| `xray del` | Deletes one JSON file | Removes frontend route where possible, refreshes Mihomo YAML. |
| `xray fix-all` | Rebuilds all managed configs | Refreshes Mihomo YAML. |
| `xray refresh-sub` | Writes `/etc/xray/sub/mihomo.yaml` and token | Adds static HTTP subscription route. |
| `xray update` | Updates core/script/data/frontend components | May restart services. |
| `xray uninstall` | Removes project-managed files | May remove or preserve Caddy/Nginx depending on selected mode. |

## Error Handling and Validation

The project uses shell-level checks plus targeted service validation:

- JSON construction uses `jq`.
- Port availability is checked before new inbounds are created.
- Domain DNS is checked before automatic TLS setup.
- Nginx configuration is tested before reload where practical.
- Caddy/Nginx path consistency is checked after route generation.
- Errors are reported through `err` or `error_out`, with newer code preferring structured `error_out` messages.

## Deployment and Release Model

The release package contains:

- `install.sh`
- `xray.sh`
- `src/`

`install.sh` installs dependencies, downloads Xray Core and optional frontend components, copies scripts into `/etc/xray/sh`, and links `/usr/local/bin/xray` to the installed script entrypoint.

## Design Tradeoffs

- Static files are preferred over daemonized control services. This lowers operational complexity but means some features refresh on command execution rather than continuously.
- Shell scripts keep installation simple on minimal Linux systems, but require careful quoting and validation.
- Nginx offers better multi-site coexistence; Caddy offers simpler automatic TLS.
- Generated frontend snippets are intentionally separated into `.add` files to reduce conflict with user-owned site config.
- Mihomo generation reads managed Xray JSON files instead of storing duplicate subscription metadata.

## Future Improvements

- Add automated protocol compatibility tests for Xray profile generation and Mihomo export.
- Split `core.sh` into smaller modules for command routing, protocol parsing, config generation, and lifecycle operations.
- Add a formal schema or validation step for generated Mihomo YAML.
- Track generated frontend blocks with stronger markers for safer deletion and updates.
- Document which Xray profiles are exportable to Mihomo and which are Xray-only.
