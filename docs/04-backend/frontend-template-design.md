# 前端模板设计

## 目标

本文档定义 Phase 3 的 Nginx/Caddy 模板化设计。它把 TLS 前端配置拆成三层：

- 模板渲染：从 `protocol.Profile` 生成 `.conf` 或 `.add` 文本。
- 配置检查：解析现有 `.conf/.add`，判断追加、幂等或冲突。
- 操作计划：列出应执行的 validate/reload/certbot 命令，但不在 Phase 3 自动执行。

## 包结构

```text
internal/frontend/nginx/
  render.go
  inspect.go
  certbot.go
  plan.go

internal/frontend/caddy/
  render.go
  inspect.go
  plan.go
```

这些包只依赖标准库和 `internal/protocol`。

## Nginx 模板

### 完整站点

完整站点用于域名第一次启用 TLS 前端协议：

- 80 server:
  - `location /.well-known/acme-challenge/`
  - `root /var/www/certbot`
  - 其他路径 301 跳转 HTTPS
- 443 server:
  - `listen 443 ssl http2`
  - `server_name {domain}`
  - `ssl_certificate /etc/nginx/ssl/{domain}/fullchain.pem`
  - `ssl_certificate_key /etc/nginx/ssl/{domain}/privkey.pem`
  - 一个主协议 location
  - `include /etc/nginx/xray/{domain}.conf.add;`

### `.add` 片段

追加片段用于同域名多协议共存：

| network | Nginx route |
| --- | --- |
| `ws` | `location {path}` + `proxy_pass http://127.0.0.1:{port}` + Upgrade headers |
| `xhttp` | `location {path}` + `proxy_pass http://127.0.0.1:{port}` |
| `grpc` | `location {serviceName}/` + `grpc_pass grpc://127.0.0.1:{port}` |

Trojan XHTTP 使用与 VLESS XHTTP 相同的前端 route，只改变后端 Xray 协议。

## Caddy 模板

### 完整站点

完整站点格式：

```caddyfile
example.com {
    encode gzip

    reverse_proxy /xray-test 127.0.0.1:10002

    import /etc/caddy/WangYan-Good/example.com.conf.add
}
```

### `.add` 片段

| network | Caddy route |
| --- | --- |
| `ws` | `reverse_proxy {path} 127.0.0.1:{port}` |
| `xhttp` | `reverse_proxy {path} 127.0.0.1:{port}` |
| `grpc` | `reverse_proxy {serviceName}/* h2c://127.0.0.1:{port}` |

## 路径规范化

Nginx：

- `/xray-test` 与 `/xray-test/` 视为同一路径。
- gRPC 输出必须以 `/` 结尾。
- `location = /sub/mihomo` 属于 Mihomo 订阅 route，不参与普通协议冲突检测。

Caddy：

- `/xray-test`、`/xray-test/`、`/xray-test/*` 视为同一路径。
- gRPC 输出使用 `/*`。

## 冲突检测

检查结果：

| 结果 | 含义 |
| --- | --- |
| `append` | path 不存在，可以追加到 `.add`。 |
| `idempotent` | path 已存在且 upstream port 相同，可以跳过。 |
| `conflict` | path 已存在但 upstream port 不同，必须阻止追加。 |

检查输入为主 `.conf` 文本、`.add` 文本和待追加 Profile，不直接读文件。

## include/import 修复

Nginx：

- 若主配置已包含 `include /etc/nginx/xray/{domain}.conf.add;`，保持不变。
- 若缺失，则插入到最后一个 `server { ... }` 的闭合 `}` 前。

Caddy：

- 若主配置已包含 `import /etc/caddy/WangYan-Good/{domain}.conf.add`，保持不变。
- 若缺失，则插入到站点块最后一个 `}` 前。

修复函数只返回修复后的文本，不写文件。

## Certbot renewal

Phase 3 Go 模型固定 Nginx webroot-first 语义：

- `authenticator = webroot` 且包含 `/var/www/certbot` 时为可接受。
- `authenticator = standalone` 必须生成迁移后的 renewal 文本。
- 迁移结果必须包含：
  - `authenticator = webroot`
  - `webroot_path = /var/www/certbot,`
  - `[[webroot_map]]`
  - `{domain} = /var/www/certbot`

## 操作计划

Phase 3 不执行命令，只生成计划：

Nginx：

- `nginx -t`
- `systemctl reload nginx`
- `certbot certonly --webroot -w /var/www/certbot -d {domain}`
- `certbot renew --dry-run --deploy-hook systemctl reload nginx`

Caddy：

- `caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile`
- `systemctl reload caddy`

后续阶段若接入 Runner，必须保留 fake runner 测试，不允许把系统命令散落在模板代码里。
