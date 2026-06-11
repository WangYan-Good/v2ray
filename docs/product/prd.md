# Product Requirements Document (PRD)
## Xray Management Script

| Field | Value |
|-------|-------|
| **Product Name** | Xray Management Script |
| **Version** | v1.2.0 |
| **Author** | WangYan-Good |
| **Repository** | https://github.com/WangYan-Good/xray |
| **Last Updated** | 2026-05-05 |
| **Status** | Active |

---

## 1. Product Overview

A bash-based command-line tool for deploying, managing, and operating Xray proxy servers on Linux systems. It provides one-click installation, multi-protocol configuration management, automatic TLS certificate provisioning, and Mihomo/Clash subscription generation.

### 1.1 Target Users

- System administrators managing proxy infrastructure
- Individual users deploying personal proxy servers
- Users requiring quick Xray node setup without manual JSON editing

### 1.2 Supported Platforms

| OS | Package Manager |
|----|-----------------|
| Ubuntu / Debian | apt-get |
| CentOS | yum |

| Architecture |
|--------------|
| x86_64 (amd64) |
| ARM64 (aarch64 / armv8) |

---

## 2. Core Features

### 2.1 Installation & Setup

| ID | Requirement | Priority |
|----|-------------|----------|
| INST-001 | One-click install with automatic dependency resolution (wget, unzip, jq) | P0 |
| INST-002 | Download Xray-core from GitHub releases with SHA256 integrity verification | P0 |
| INST-003 | Support custom core version via `-v` flag | P1 |
| INST-004 | Support custom core file via `-f` flag | P1 |
| INST-005 | Support proxy download via `-p` flag | P1 |
| INST-006 | Support local install via `-l` flag | P2 |
| INST-007 | Register systemd service for Xray lifecycle management | P0 |
| INST-008 | Detect existing installation and offer reinstall/reinstall-after-uninstall/exit options | P1 |
| INST-009 | Auto-sync system time via `timedatectl set-ntp` | P1 |
| INST-010 | Configure system limits (LimitNOFILE=1048576) and log rotation | P1 |

### 2.2 Protocol Support

| ID | Protocol | Priority |
|----|----------|----------|
| PROTO-001 | VMess-TCP | P0 |
| PROTO-002 | VMess-mKCP | P1 |
| PROTO-003 | VMess-QUIC | P1 |
| PROTO-004 | VMess-H2-TLS | P1 |
| PROTO-005 | VMess-WS-TLS | P0 |
| PROTO-006 | VMess-gRPC-TLS | P1 |
| PROTO-007 | VLESS-H2-TLS | P1 |
| PROTO-008 | VLESS-WS-TLS | P0 |
| PROTO-009 | VLESS-gRPC-TLS | P1 |
| PROTO-010 | VLESS-XHTTP-TLS | P0 |
| PROTO-011 | VLESS-XTLS-uTLS-REALITY | P0 |
| PROTO-012 | Trojan-H2-TLS | P1 |
| PROTO-013 | Trojan-WS-TLS | P1 |
| PROTO-014 | Trojan-gRPC-TLS | P1 |
| PROTO-015 | Trojan-XHTTP-TLS | P1 |
| PROTO-016 | Shadowsocks | P0 |
| PROTO-017 | Socks | P2 |
| PROTO-018 | Dynamic Port (VMess-TCP/mKCP/QUIC) | P2 |

### 2.3 Configuration Management

| ID | Requirement | Priority |
|----|-------------|----------|
| CFG-001 | Add configuration via interactive menu or command-line arguments | P0 |
| CFG-002 | View configuration details (protocol, address, port, UUID, path, TLS, URL, etc.) | P0 |
| CFG-003 | Delete configuration by name (direct, no confirmation) | P0 |
| CFG-004 | Batch delete multiple configurations (`ddel`) | P1 |
| CFG-005 | Modify protocol, port, domain, path, password, UUID, encryption method, header type, target address, target port, key pair, SNI, dynamic port, website, mKCP seed, username | P0 |
| CFG-006 | Auto-generate random values for UUID, port, path, password, encryption method | P1 |
| CFG-007 | Fix individual or all configuration files (`fix`, `fix-all`) | P1 |
| CFG-008 | Validate input (number, port, domain, path, UUID format) | P0 |
| CFG-009 | Output client-side JSON for testing (`client`, `genc`, `gen`) | P1 |

### 2.4 TLS Certificate Management

| ID | Requirement | Priority |
|----|-------------|----------|
| TLS-001 | Support Caddy as TLS provider (auto HTTPS, simple config) | P0 |
| TLS-002 | Support Nginx + Certbot as TLS provider (flexible, multi-site) | P0 |
| TLS-003 | Auto-detect existing Caddy/Nginx installation and prompt user | P1 |
| TLS-004 | Prevent port conflict when both Caddy and Nginx are running | P0 |
| TLS-005 | Auto-configure reverse proxy rules for each protocol transport (ws/grpc/xhttp/h2) | P0 |
| TLS-006 | Allow skip auto-TLS (`no-auto-tls`) for manual certificate scenarios | P1 |
| TLS-007 | Repair Caddyfile or Nginx configuration (`fix-caddyfile`, `fix-nginxfile`) | P1 |

### 2.5 Mihomo/Clash Subscription

| ID | Requirement | Priority |
|----|-------------|----------|
| SUB-001 | Generate Mihomo-compatible YAML subscription from all configurations | P0 |
| SUB-002 | Support single-target subscription via config file path | P1 |
| SUB-003 | Token-based authentication for subscription endpoint | P0 |
| SUB-004 | Auto-configure HTTP route in Caddy or Nginx | P0 |
| SUB-005 | Display subscription URL (`sub-url`) | P0 |
| SUB-006 | Refresh subscription file and update web server config (`refresh-sub`) | P0 |

### 2.6 Service Management

| ID | Requirement | Priority |
|----|-------------|----------|
| SVC-001 | Start / Stop / Restart Xray service | P0 |
| SVC-002 | Start / Stop / Restart Caddy or Nginx | P1 |
| SVC-003 | Check running status (`status`) | P0 |
| SVC-004 | Test configuration validity (`test`) | P0 |
| SVC-005 | View access log and error log (`log`, `logerr`) | P0 |

### 2.7 Update & Maintenance

| ID | Requirement | Priority |
|----|-------------|----------|
| UPD-001 | Update Xray-core to latest or specified version | P0 |
| UPD-002 | Update management script to latest version | P0 |
| UPD-003 | Update geoip.dat and geosite.dat (Loyalsoldier rules) | P1 |
| UPD-004 | Update Caddy to latest version | P1 |
| UPD-005 | Reinstall Nginx + Certbot via package manager | P1 |
| UPD-006 | Update script itself (`update.sh`) | P0 |

### 2.8 Uninstall

| ID | Requirement | Priority |
|----|-------------|----------|
| UN-001 | Remove all Xray files (scripts, core, configs, logs, systemd service) | P0 |
| UN-002 | Clean up bashrc alias and command link | P0 |
| UN-003 | Optional: stop and remove Caddy | P1 |
| UN-004 | Optional: stop and remove Nginx | P1 |

### 2.9 Utilities

| ID | Requirement | Priority |
|----|-------------|----------|
| UTIL-001 | Enable BBR congestion control (if supported) | P2 |
| UTIL-002 | Configure DNS settings | P1 |
| UTIL-003 | Generate QR code for configuration | P1 |
| UTIL-004 | Generate shareable URL for configuration | P1 |
| UTIL-005 | Display current script and core version | P0 |
| UTIL-006 | Get server public IP | P1 |
| UTIL-007 | Get an available random port | P2 |
| UTIL-008 | Run raw Xray binary commands (`bin`) | P1 |

---

## 3. Non-Functional Requirements

### 3.1 Security

| ID | Requirement | Priority |
|----|-------------|----------|
| SEC-001 | Require root privileges for installation | P0 |
| SEC-002 | SHA256 checksum verification for Xray-core and Caddy downloads | P0 |
| SEC-003 | Token-based access control for subscription endpoint | P0 |
| SEC-004 | TLS 1.2+ enforcement for all downloads | P0 |
| SEC-005 | Token file permissions set to 600 | P1 |
| SEC-006 | Subscription file permissions set to 644 | P1 |

### 3.2 Reliability

| ID | Requirement | Priority |
|----|-------------|----------|
| REL-001 | Retry downloads up to 3-5 times on failure | P0 |
| REL-002 | Rollback partially installed files on failure | P0 |
| REL-003 | Validate port availability before binding (netstat/ss fallback) | P1 |
| REL-004 | Auto-retry port randomization up to 233 attempts | P1 |

### 3.3 Maintainability

| ID | Requirement | Priority |
|----|-------------|----------|
| MAINT-001 | Pass ShellCheck with severity=warning (excluded rules documented in CI) | P0 |
| MAINT-002 | Pass `bash -n` syntax validation for all `.sh` files | P0 |
| MAINT-003 | All `.json` files must be valid JSON | P0 |
| MAINT-004 | No V2Ray/v2ray remnants in source code (except legitimate contexts) | P0 |
| MAINT-005 | All required protocols must be present in `protocol_list` | P0 |

### 3.4 Performance

| ID | Requirement | Priority |
|----|-------------|----------|
| PERF-001 | Sequential download to avoid race conditions | P1 |
| PERF-002 | Background execution for non-blocking operations (package install, service restart) | P2 |

---

## 4. Architecture

### 4.1 Directory Structure

```
/etc/xray/
├── bin/                    # Xray-core binary and geo data
│   ├── xray
│   ├── geoip.dat
│   └── geosite.dat
├── conf/                   # Per-config JSON files
│   ├── vmess-ws-tls.json
│   ├── vless-reality.json
│   └── ...
├── sh/                     # Management scripts
│   ├── src/
│   │   ├── core.sh         # Core logic (protocol, config, menu)
│   │   ├── caddy.sh        # Caddy TLS provider
│   │   ├── nginx.sh        # Nginx TLS provider
│   │   ├── mihomo.sh       # Mihomo/Clash subscription generator
│   │   ├── download.sh     # Download and update logic
│   │   ├── help.sh         # Help documentation
│   │   ├── dns.sh          # DNS configuration
│   │   ├── bbr.sh          # BBR congestion control
│   │   ├── init.sh         # Initialization and shared utilities
│   │   ├── systemd.sh      # systemd service management
│   │   └── log.sh          # Log rotation setup
│   └── xray.sh             # Entry point
└── config.json             # Main Xray config (auto-generated)

/etc/caddy/                 # Caddy configuration (if selected)
/etc/nginx/                 # Nginx configuration (if selected)
/var/log/xray/              # Log directory
/usr/local/bin/xray         # Command symlink -> /etc/xray/sh/xray.sh
```

### 4.2 Module Dependencies

```
install.sh
  └── download.sh (pkg install, file download)
  └── init.sh (shared vars, msg, err)

xray.sh (entry point)
  └── init.sh (load shared functions)
      └── core.sh (main menu, add/change/del/info)
          ├── caddy.sh (TLS via Caddy)
          ├── nginx.sh (TLS via Nginx)
          ├── mihomo.sh (subscription)
          ├── download.sh (update)
          ├── help.sh (help output)
          ├── dns.sh (DNS)
          ├── bbr.sh (BBR)
          ├── systemd.sh (service)
          └── log.sh (logrotate)
```

---

## 5. CLI Interface

### 5.1 Installation Flags

```
install.sh [-f <file>] [-l] [-p <proxy>] [-v <version>] [--tls <caddy|nginx>] [--uninstall] [-h]
```

### 5.2 Runtime Commands

```
xray <command> [arguments...]

Basic:
  v, version                        Show current version
  ip                                Return server public IP
  get-port                          Return an available port

General:
  a, add [protocol] [args...|auto]  Add a configuration
  c, change [name] [option] [args]  Modify a configuration
  d, del [name]                     Delete a configuration
  i, info [name]                    View configuration details
  qr [name]                         QR code output
  url [name]                        Shareable URL output
  mihomo, clash [name]              Output Mihomo YAML subscription
  refresh-sub [domain]              Refresh subscription file + HTTP endpoint
  sub-url [domain]                  Display subscription URL
  log                               View access log
  logerr                            View error log

Modification:
  dp, dynamicport [name] ...        Change dynamic port range
  full [name] [...]                 Change multiple parameters
  id [name] [uuid|auto]             Change UUID
  host [name] [domain]              Change domain/host
  port [name] [port|auto]           Change port
  path [name] [path|auto]           Change path
  passwd [name] [password|auto]     Change password
  type [name] [type|auto]           Change header type
  method [name] [method|auto]       Change encryption method
  seed [name] [seed|auto]           Change mKCP seed
  new [name] [...]                  Change protocol
  web [name] [domain]               Change website

Advanced:
  dns [...]                         Configure DNS
  dd, ddel [name...]                Delete multiple configurations
  fix [name]                        Fix a configuration file
  fix-all                           Fix all configuration files
  fix-caddyfile                     Repair Caddyfile
  fix-nginxfile                     Repair Nginx config
  fix-config.json                   Repair main config.json

Management:
  un, uninstall                     Uninstall everything
  u, update [component] [version]   Update a component
  U, update.sh                      Update management script
  s, status                         Show running status
  start, stop, restart [service]    Service control
  t, test                           Test configuration
  reinstall                         Reinstall script

Testing:
  client [name]                     Output client-side JSON
  debug [name]                      Output debug information
  gen [...]                         Generate JSON without creating files
  genc [name]                       Output client partial JSON
  no-auto-tls [...]                 Add without auto-TLS
  xapi [...]                        API with current running Xray backend

Other:
  bbr                               Enable BBR (if supported)
  bin [...]                         Run raw Xray binary commands
  api, convert, tls, run, uuid      Compatibility with Xray native commands
  h, help                           Show this help
```

---

## 6. Error Codes

| Code | Name | Description |
|------|------|-------------|
| 1 | ERR_DOWNLOAD | Download failure (core, script, jq) |
| 2 | ERR_CHECKSUM | SHA256 checksum mismatch |
| 3 | ERR_PERMISSION | Non-root user attempting installation |
| 4 | ERR_ARCH | Unsupported architecture (not x86_64 or ARM64) |
| 5 | ERR_DEPENDENCY | Missing system dependency (apt/yum, systemctl, etc.) |
| 6 | ERR_CERT | TLS certificate failure |
| 7 | ERR_CONFIG | Configuration or installation error |
| 8 | ERR_SERVICE | systemd service management failure |

---

## 7. CI/CD Pipeline

| Job | Trigger | Checks |
|-----|---------|--------|
| **ShellCheck** | push to develop/main/master, PR to develop/main/master | Static analysis on all `.sh` files (excluding core.sh), with documented rule exclusions |
| **Bash Syntax** | push to develop/main/master, PR to develop/main/master | `bash -n` syntax validation on all `.sh` files |
| **Automated Testcases** | push to develop/main/master, PR to develop/main/master, manual dispatch | Runs `tests/run.sh`, covering scripted `testcase-*.sh` workflow, release packaging contracts, protocol contracts, and deployment regression guards |
| **JSON Validation** | push to develop/main/master, PR to develop/main/master | All `.json` files must parse successfully via `jq` |
| **Naming Consistency** | push to develop/main/master, PR to develop/main/master | No V2Ray/v2ray remnants in source (except allowed contexts) |
| **Protocol Completeness** | push to develop/main/master, PR to develop/main/master | All 8 required protocols present in `protocol_list` |

---

## 8. External Dependencies

| Dependency | Source | Purpose |
|------------|--------|---------|
| Xray-core | github.com/XTLS/Xray-core | Core proxy engine |
| jq | github.com/jqlang/jq | JSON parsing and generation |
| geoip.dat / geosite.dat | github.com/Loyalsoldier/v2ray-rules-dat | GeoIP and GeoSite routing rules |
| Caddy (optional) | github.com/caddyserver/caddy | Automatic TLS provisioning |
| Nginx (optional) | apt/yum packages | Reverse proxy + Certbot for TLS |
| Certbot (optional) | apt/yum packages | Let's Encrypt certificate management |

---

## 9. Glossary

| Term | Definition |
|------|------------|
| **Xray** | High-performance proxy core supporting multiple protocols |
| **Mihomo / Clash** | Proxy client software compatible with YAML subscription format |
| **TLS** | Transport Layer Security, for encrypted connections |
| **REALITY** | Xray's TLS fingerprinting bypass technology |
| **XHTTP** | Extended HTTP transport protocol for Xray |
| **BBR** | Google's TCP congestion control algorithm |
| **UUID** | Universally Unique Identifier, used as user identity in VMess/VLESS |
