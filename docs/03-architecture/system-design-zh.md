# 系统设计

## 概述

本项目是一个 Xray 安装与管理脚本。它负责安装 Xray Core、管理入站（inbound）配置文件、可选地通过 Caddy 或 Nginx 配置 TLS 前端，并提供辅助命令用于客户端配置生成、URL/二维码输出、诊断、更新以及 Mihomo 订阅生成。

运行时模型采用**文件驱动**设计：

- Xray 使用一个主配置文件加一个配置目录运行。
- 每个受管理的代理节点由 `/etc/xray/conf` 下的一个 JSON 文件表示。
- Caddy 或 Nginx 管理公共 TLS 入口点，并将指定路径反向代理到本地 Xray 入站端口。
- Go CLI 命令 `xray` 是默认用户面向控制平面；未迁移命令通过 Bash legacy 入口委托执行。

## 设计目标

- 提供低摩擦的 Xray 安装与管理流程。
- 支持在同一服务器上运行多个协议配置。
- 允许多个 TLS 代理节点在同一域名或跨多个域名共存。
- 在可能的情况下，兼容用户自行管理的 Nginx/Caddy 站点。
- 通过文件保持运行状态透明且可恢复。
- 避免运行自定义长期守护进程；依赖 systemd、Xray、Nginx、Caddy 和静态文件。

## 非目标

- 不提供 Web 管理面板。
- 不是通用的订阅格式转换工具。
- 不为订阅生成运行自定义 HTTP API 服务器。
- 不替代 Xray Core 的协议验证能力。

## 运行时布局

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

Nginx 模式：

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

Caddy 模式：

```text
/etc/caddy/
|-- Caddyfile
|-- WangYan-Good/
|   |-- example.com.conf
|   `-- example.com.conf.add
`-- sites/
```

## 主要组件

| 组件 | 文件 | 职责 |
|------|------|------|
| 入口点 | `xray.sh` | 加载 `init.sh` 并分发命令参数。 |
| 引导模块 | `src/init.sh` | 定义路径、检测架构、加载状态、检测 Caddy/Nginx、加载 `core.sh`。 |
| 核心命令路由 | `src/core.sh` | 实现 `add`、`change`、`del`、`info`、`url`、`qr`、`client`、更新、服务控制，并分发到功能模块。 |
| Xray 配置构建器 | `src/core.sh` | 构建 Xray 入站 JSON 文件及主配置文件 `/etc/xray/config.json`。 |
| Caddy 集成 | `src/caddy.sh` | 创建 Caddyfile 导入和反向代理块，支持 WS、gRPC、H2/XHTTP 及回退站点。 |
| Nginx 集成 | `src/nginx.sh` | 创建 Nginx server/location 块，通过 Certbot 获取证书，验证并重载 Nginx。 |
| Mihomo 订阅 | `src/mihomo.sh` | 生成静态 Mihomo YAML、token、订阅 URL 及 Web 服务器路由片段。 |
| 下载模块 | `src/download.sh` | 下载 Xray Core、数据文件、Caddy、Nginx 及依赖资源。 |
| 服务单元 | `src/systemd.sh` | 编写 Xray 和 Caddy 的 systemd 服务定义文件。 |
| 运维辅助 | `src/log.sh`、`src/dns.sh`、`src/bbr.sh` | 日志管理、DNS 设置和 BBR 辅助工具。 |

## 命令流程

```text
用户
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

## 配置模型

脚本将 `/etc/xray/conf/*.json` 视为受管理节点状态的**唯一来源**。每个文件包含一个 Xray 入站配置。主配置文件 `/etc/xray/config.json` 包含服务级共享设置：

- 日志
- DNS
- API 与统计
- 路由
- 基础出站定义

Xray 启动命令为：

```text
xray run -config /etc/xray/config.json -confdir /etc/xray/conf
```

创建新节点时，`core.sh` 执行以下步骤：

1. 解析请求的协议配置档。
2. 解析或询问域名、端口、UUID、路径、密码及传输层特定字段。
3. 通过 `jq` 构建入站 JSON。
4. 写入单节点 JSON 文件。
5. 在可能的情况下，通过 Xray API 将其添加到运行中的 Xray 进程（热加载）。
6. 当启用 TLS 模式时，生成或更新 Caddy/Nginx 前端配置。
7. 刷新静态 Mihomo 订阅文件。

## TLS 前端模型

TLS 代理传输通常在 Xray 内部监听 `127.0.0.1`。Caddy 或 Nginx 负责终止公共 TLS 并将流量代理到本地入站端口。

典型的 WS 流程：

```text
客户端
  |
  | TLS + WebSocket /path
  v
Caddy/Nginx :443
  |
  | reverse_proxy /path
  v
Xray 入站 127.0.0.1:随机端口
```

非 TLS TCP、mKCP、QUIC、Shadowsocks、Socks 和 REALITY 配置直接绑定为 Xray 入站，**不需要** Caddy/Nginx 反向代理。

## 多站点与多协议设计

对于一个域名下多个 Xray 传输层，项目使用**分离文件模型**：

- `domain.conf` 包含主 TLS server 块。
- `domain.conf.add` 包含追加的路由，如额外的 `location` 或 `reverse_proxy` 块。

这使得生成的 Xray 路由与用户管理的站点内容分离，并允许多个协议路径在同一域名下共存。

对于 Nginx，项目还保留 `/etc/nginx/sites-enabled` 用于非 Xray 站点。

## Mihomo 订阅设计

Mihomo 支持采用**静态 YAML 生成**，而非请求时实时执行 shell 命令。

命令：

```bash
xray mihomo [名称]
xray refresh-sub [域名]
xray sub-url [域名]
```

文件：

```text
/etc/xray/sub/mihomo.yaml
/etc/xray/sub/token
```

流程：

```text
add/change/del/fix-all
  |
  v
src/mihomo.sh
  |
  v
生成 /etc/xray/sub/mihomo.yaml

xray refresh-sub example.com
  |
  +-- 刷新 YAML 文件
  +-- 如缺失则创建 token
  +-- 追加 /sub/mihomo 路由到 Caddy 或 Nginx
  +-- 打印 https://example.com/sub/mihomo?token=...
```

HTTP 服务器仅提供静态文件并检查生成路由中的 token。它**不会**在请求时执行 shell 命令。

## 协议配置档模型

项目通过 `src/core.sh` 中的 `protocol_list` 暴露协议配置档。

当前配置档族：

- VMess：TCP、mKCP、QUIC、H2/XHTTP、WS、gRPC、动态端口变体。
- VLESS：H2/XHTTP、WS、gRPC、XTLS-uTLS-REALITY。
- Trojan：H2/XHTTP、WS、gRPC。
- Shadowsocks。
- Socks。

内部解析器将配置档名称映射到：

- `is_protocol`：Xray 协议，如 `vmess`、`vless`、`trojan`、`shadowsocks`、`socks`。
- `net`：传输族，如 `tcp`、`kcp`、`quic`、`ws`、`grpc`、`xhttp`、`reality`、`ss`、`socks`。
- `json_str` / `is_stream`：Xray 入站设置和流媒体设置。

Mihomo 订阅支持是一个**独立的兼容层**。一个协议配置档对 Xray 有效，但如果 Mihomo 缺少相同的传输语义，可能无法导出到 Mihomo。

## 状态与副作用

| 操作 | 主要状态变更 | 次要副作用 |
|------|-------------|-----------|
| `xray add` | 在 `/etc/xray/conf` 下添加一个 JSON 文件 | 更新 Xray API/运行时、Caddy/Nginx 路由、Mihomo YAML。 |
| `xray change` | 重建或编辑一个受管理的 JSON 文件 | 可能更新 TLS 前端路由并重载服务。 |
| `xray del` | 删除一个 JSON 文件 | 尽可能移除前端路由，刷新 Mihomo YAML。 |
| `xray fix-all` | 重建所有受管理的配置 | 刷新 Mihomo YAML。 |
| `xray refresh-sub` | 写入 `/etc/xray/sub/mihomo.yaml` 和 token | 添加静态 HTTP 订阅路由。 |
| `xray update` | 更新核心/脚本/数据/前端组件 | 可能重启服务。 |
| `xray uninstall` | 移除项目管理的文件 | 根据选择的模式，可能保留或移除 Caddy/Nginx。 |

## 错误处理与验证

项目使用 shell 级检查结合定向服务验证：

- JSON 构建使用 `jq`。
- 创建新入站前检查端口可用性。
- 自动 TLS 配置前检查域名 DNS 解析。
- 重载前尽可能测试 Nginx 配置（`nginx -t`）。
- 路由生成后检查 Caddy/Nginx 路径一致性。
- 错误通过 `err` 或 `error_out` 报告，新代码优先使用结构化的 `error_out` 消息。

## 部署与发布模型

发布包包含：

- `install.sh`
- `xray.sh`
- `src/`

`install.sh` 负责安装依赖、下载 Xray Core、Go CLI 和可选前端组件，将 Bash legacy 脚本复制到 `/etc/xray/sh`，并将 `/usr/local/bin/xray` 安装为 Go CLI 入口。未迁移命令由 Go legacy 层委托到 `/etc/xray/sh/xray.sh`。

## 设计权衡

- **优先使用静态文件而非守护进程控制服务**。这降低了运维复杂度，但也意味着某些功能在命令执行时刷新，而非持续运行。
- **shell 脚本在精简 Linux 系统上保持安装简单**，但需要谨慎的引号使用和验证。
- **Nginx 提供更好的多站点共存能力**；Caddy 提供更简单的自动 TLS。
- **生成的前端片段有意分离到 `.add` 文件**，以减少与用户自有站点配置的冲突。
- **Mihomo 生成读取受管理的 Xray JSON 文件**，而非存储重复的订阅元数据。

## 未来改进方向

- 为 Xray 配置档生成和 Mihomo 导出添加自动化协议兼容性测试。
- 将 `core.sh` 拆分为更小的模块：命令路由、协议解析、配置生成和生命周期操作。
- 为生成的 Mihomo YAML 添加正式的模式定义或验证步骤。
- 使用更强的标记跟踪生成的前端块，以实现更安全的删除和更新。
- 文档化哪些 Xray 配置档可导出到 Mihomo，哪些是 Xray 独有的。
