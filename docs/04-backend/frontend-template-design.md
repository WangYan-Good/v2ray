# 前端模板设计

## 目标

本文档定义 Nginx/Caddy 模板和 Nginx 事务部署。它把 TLS 前端配置拆成四层：

- 模板渲染：从 `protocol.Profile` 生成 `.conf` 或 `.add` 文本。
- 配置检查：解析现有 `.conf/.add`，判断追加、幂等或冲突。
- 系统执行：所有 Nginx、Certbot、OpenSSL、systemctl 命令通过 Runner 执行。
- 事务部署：候选验证、原子提交、服务 reload 与失败回滚。

## 包结构

```text
internal/frontend/nginx/
  render.go
  inspect.go
  certbot.go
  plan.go
  transaction.go
  deploy.go

internal/frontend/caddy/
  render.go
  inspect.go
  plan.go
```

渲染、解析和迁移函数保持无副作用；`deploy.go` 是唯一的 Nginx 编排边界。

## Nginx 模板

### 完整站点

首次无证书时先生成只监听 80 的 bootstrap：ACME challenge 使用
`/var/www/certbot` 和 `try_files`，普通请求返回 503。证书验证成功后才写入完整站点：

- 80 server:
  - `location /.well-known/acme-challenge/`
  - `root /var/www/certbot`
  - 其他路径 301 跳转 HTTPS
- 443 server:
  - `listen 443 ssl http2`
  - `server_name {domain}`
  - `ssl_certificate /etc/letsencrypt/live/{domain}/fullchain.pem`
  - `ssl_certificate_key /etc/letsencrypt/live/{domain}/privkey.pem`
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

签发固定使用 `certbot certonly --webroot --non-interactive --agree-tos`。
邮箱来自 `/etc/xray/acme.json`；无邮箱必须显式选择。部署 hook 位于
`/etc/letsencrypt/renewal-hooks/deploy/xray-nginx-reload`，权限 0755，并在
`systemctl reload nginx` 前运行 `nginx -t`。

## 操作计划

实际部署顺序：

Nginx：

- preflight、端口/route 冲突检查和备份
- bootstrap 候选验证、原子提交、`nginx -t`、reload
- Certbot webroot 签发和 OpenSSL 文件/域名验证
- final 候选验证、原子提交、`nginx -t`、reload
- 持久 hook、renewal 迁移和首次 `certbot renew --dry-run`

Caddy：

- `caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile`
- `systemctl reload caddy`

失败时恢复管理文件，并只在恢复后的 `nginx -t` 成功时 reload。已经成功
签发的证书和 renewal 元数据不会删除。旧 `/etc/nginx/ssl/{domain}` 仅在
Let’s Encrypt 证书验证通过时迁移；未知自定义证书和软链接保持不变。
