# VPS 验收记录：bak.proxy.yourdie.com

日期: 2026-07-06 Asia/Shanghai；远端时间 2026-07-05 22:35-23:11 -0500
主机: `bak.proxy.yourdie.com`
公网 IP: `107.174.218.158`
系统: AlmaLinux 9.7
架构: x86_64
Xray-core: `Xray 26.3.27`
当前入口: Go binary `/usr/local/bin/xray`
远端工作区: `/root/xray-vps-acceptance-20260705-223514`

## 执行摘要

- SSH 使用 `ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@bak.proxy.yourdie.com`。
- 远端已备份 `/etc/xray`、`/etc/nginx`、`/etc/letsencrypt`、`/usr/local/bin/xray` 和服务状态，并生成 `rollback.sh`。
- 远端通过 Podman 运行官方 `docker.io/library/golang:1.22` 镜像完成 `go test ./...`、构建和部署。
- `/usr/local/bin/xray` 已替换为当前 Go CLI；`/etc/xray/sh` 最终确认不存在。
- 发布和远程一键安装能力保留：release 发布 `install.sh`、Linux tarball 和 `checksums.txt`；`install.sh` 下载 Go CLI 后执行 `xray install`。

## 本地与远端测试

- 本地通过:
  - `go test ./...`
  - `bash tests/run.sh`
  - `bash tests/shellcheck.sh`
- 远端通过:
  - `go test ./...`
  - `bash tests/run.sh`
  - `bash tests/shellcheck.sh`
- 远端最终回归:
  - `xray status`: `node_count = 3`
  - `xray switch-plan`: `runtime = go`
  - `xray test`: `Configuration OK`
  - `nginx -t`: successful，保留既有 OCSP stapling warning
  - `systemctl is-active xray nginx`: 均为 `active`

## 真实服务验收

- 初始生产节点为 3 个:
  - `Trojan-gRPC-TLS-bak.proxy.yourdie.com.json`
  - `VLESS-gRPC-TLS-bak.proxy.yourdie.com.json`
  - `VMess-gRPC-TLS-bak.proxy.yourdie.com.json`
- 本轮临时创建并清理的测试节点:
  - VLESS WS TLS
  - VLESS XHTTP TLS
  - Trojan XHTTP TLS
  - VMess TCP
  - Shadowsocks
  - Socks
  - VLESS REALITY
- 真实客户端连通性通过:
  - `VLESS-WS-TLS-bak.proxy.yourdie.com`
  - `VLESS-XHTTP-TLS-bak.proxy.yourdie.com`
  - `Trojan-XHTTP-TLS-bak.proxy.yourdie.com`
  - `VLESS-gRPC-TLS-bak.proxy.yourdie.com`
  - `VMess-TCP-31003`
  - `Shadowsocks-31004`
  - `Socks-31005`
- 代理验证方式: `xray --server bak.proxy.yourdie.com client <name>` 生成 full client config，临时启动 `/etc/xray/bin/xray run -config client.json`，再通过 `curl --socks5-hostname 127.0.0.1:2333 https://www.cloudflare.com/cdn-cgi/trace` 验证出口 IP 为 `107.174.218.158`。
- 订阅验收:
  - `xray --server bak.proxy.yourdie.com mihomo` 成功，Trojan XHTTP 按契约输出 unsupported skip。
  - `xray --server bak.proxy.yourdie.com refresh-sub bak.proxy.yourdie.com` 成功。
  - `xray sub-url bak.proxy.yourdie.com` 返回的 HTTPS URL 可下载 YAML。
  - 最终订阅只包含原 3 个生产节点。
- Certbot 验收:
  - 发现远端 renewal 原为 `authenticator = nginx`，且旧 Nginx 站点内 Certbot 注入的 301 会阻断 webroot challenge。
  - 已通过 `xray fix-nginxfile` 对应的 Go 修复路径沉淀: 移除旧 Certbot 301 `if` 块，迁移 renewal 为 `authenticator = webroot`，保留 `webroot_path = /var/www/certbot,` 和 `[[webroot_map]]`。
  - `certbot renew --dry-run --no-random-sleep-on-renew` 最终通过。

## 发现与修复

- `--server` 过去会把直连协议地址写入 `Host`，导致 `info/client/mihomo` 误判为 TLS 前端。已新增独立 address override 并补测试。
- 订阅 Nginx 路由过去使用 prefix `location /sub/{token}/mihomo.yaml`，HTTPS 拉取返回 404。已改为 exact `location = ...` 并补测试。
- 旧 Nginx/Cerbot renewal 状态会破坏 webroot dry-run。已让 `fix-nginxfile` 修复站点内旧 301 和 renewal webroot 配置。
- REALITY 节点配置可加载、端口可监听、公私钥可由 Xray Core 校验，但本机 full client 经 SOCKS 出站仍失败:
  - HTTPS 目标: `curl: (35) OpenSSL SSL_connect: Connection reset by peer`
  - HTTP 目标: `curl: (56) Recv failure: Connection reset by peer`
  - client debug: `proxy/vless/outbound: failed to find an available destination > common/retry: [EOF]`
  - 已排除公网 hairpin、Microsoft 目标站不可达和 public key 不匹配；该项作为后续 REALITY 模板专项问题记录。

## 清理结果

- 所有测试节点已删除，测试端口 `31001-31006` 无监听。
- `xray status` 回到 `node_count = 3`。
- `xray test`、`nginx -t`、`certbot renew --dry-run` 均通过。
- `/etc/xray/sh` 不存在。
- 回滚脚本保留在远端工作区。

结论: 当前 Go 生产运行时、发布/远程安装路径、订阅、Nginx、Certbot dry-run 和除 REALITY 真实流量外的协议客户端连通性通过；REALITY 真实连通性作为后续专项 blocker。
