# Xray Go CLI PRD

## 产品目标

提供一个可远程一键安装、可发布、可测试、可回滚的 Xray 管理 CLI，覆盖节点管理、TLS 前端、订阅生成、安装更新和真实 VPS 运维验收。

## 用户场景

- VPS 用户通过一条命令安装并管理 Xray。
- 运维者添加、修改、删除节点并刷新订阅。
- 用户生成分享 URL、客户端 JSON 和 Mihomo YAML。
- 维护者通过 fixture、Go test 和真实 VPS 验收降低发布风险。

## 核心能力

- 远程安装：`install.sh` 下载 Go CLI tarball，校验 `checksums.txt`，安装 `/usr/local/bin/xray`。
- 节点管理：支持 VMess、VLESS、Trojan、Shadowsocks、Socks，以及 WS/gRPC/XHTTP/REALITY 主路径。
- TLS 前端：支持 Nginx/Caddy 模板、同域名多协议追加、订阅路由和 Certbot webroot renewal。
- 订阅：生成 Mihomo YAML、订阅 token 和订阅 URL。
- 运维：支持 status、test、start、stop、restart、update、uninstall、Xray-core passthrough。

## 非目标

- 不提供 Web 管理面板。
- 不改变 Xray-core 协议语义。
- 不发布 Bash runtime asset。
- 不在 CI 中调用真实 Certbot、systemd、公网 DNS 或真实 `/etc`。

## 生产边界

- 生产入口：`/usr/local/bin/xray` Go binary。
- 保留 shell：仅 `install.sh` 和测试 harness。
- 删除 runtime：`xray.sh`、`src/`、`/etc/xray/sh`、`code.zip`。

## 验收

- `go test ./...`
- `bash tests/run.sh`
- `bash tests/shellcheck.sh`
- Release 包含 `install.sh`、Go tarballs、`checksums.txt`。
- `<redacted-vps-domain>` 验收通过并记录。
