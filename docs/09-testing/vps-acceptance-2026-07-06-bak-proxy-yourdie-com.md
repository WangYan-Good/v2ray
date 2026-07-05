# VPS 验收记录：bak.proxy.yourdie.com

日期: 2026-07-06 Asia/Shanghai；远端时间 2026-07-05 14:09-14:35 -0500
系统: AlmaLinux 9.7 (Moss Jungle Cat)
架构: x86_64
主机: bak.proxy.yourdie.com
公网 IP: 107.174.218.158
Xray-core 版本: Xray 26.3.27
脚本版本: v1.2.0
TLS 模式: Nginx + Certbot

## 执行摘要

- SSH: `root@bak.proxy.yourdie.com`，使用 `ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=accept-new`。
- 远端工作区: `/root/xray-vps-acceptance-20260705-141023`。
- 备份: 已备份 `/etc/xray`、`/etc/nginx`、`/etc/letsencrypt/renewal`、`/usr/local/bin/xray`，并生成 `rollback.sh`。
- 部署: 当前工作树构建 Go CLI 并安装到 `/usr/local/bin/xray`；Bash legacy 更新到 `/etc/xray/sh`。
- 清理: 所有 `codex-*` 测试节点已删除，订阅已刷新，最终无测试残留。

## 验证命令

- 本地:
  - `bash tests/run.sh`
  - `bash tests/shellcheck.sh`
- 远端仓库:
  - `bash tests/run.sh`
  - `bash tests/shellcheck.sh`
  - 修复后补跑 `bash tests/testcase-06-command-matrix.sh` 与 `bash tests/shellcheck.sh`
- 真实服务:
  - `xray version`
  - `xray status`
  - `xray switch-plan`
  - `xray info/url <name>`
  - `xray add/del`
  - `xray mihomo`
  - `xray refresh-sub bak.proxy.yourdie.com`
  - `xray sub-url bak.proxy.yourdie.com`
  - `/etc/xray/bin/xray run -test -config /etc/xray/config.json`
  - `nginx -t`
  - `certbot renew --dry-run --no-random-sleep-on-renew`

## 结果摘要

- Go CLI 默认入口生效: `/usr/local/bin/xray` 为 Linux amd64 Go binary，`xray version` 输出 `xray go-cli dev`。
- 初始生产节点: `Trojan-gRPC-TLS`、`VLESS-gRPC-TLS`、`VMess-gRPC-TLS` 共 3 个。
- 协议覆盖: 添加并验证 VLESS WS、VLESS XHTTP、Trojan XHTTP、VLESS REALITY、VMess TCP、Shadowsocks、Socks。
- Nginx 多协议追加: `.conf.add` 正确追加并删除 WS/XHTTP/Trojan XHTTP location。
- 客户端连通性: VLESS WS 与 Shadowsocks 使用临时 client JSON 通过 `curl --socks5-hostname 127.0.0.1:2333 https://www.cloudflare.com/cdn-cgi/trace`，出口 IP 为 `107.174.218.158`。
- Mihomo: 预览、刷新订阅和订阅 URL 均成功；Trojan XHTTP 按设计输出 unsupported skip。
- Certbot: dry-run 成功；现有 renewal 使用 `authenticator = nginx`，本次未迁移为 webroot。
- 最终回归: `node_count = 3`，Xray 配置 `Configuration OK`，Nginx 配置测试成功，`xray`/`nginx` 服务 active，未发现 `codex-*` 残留。

## 发现与处理

- 发现 `txhttp`/`Trojan-XHTTP-TLS` 参数被通用 TLS UUID 校验误拦截，已修复。
- 发现 `vxhttp`/`txhttp` 快捷别名未明确映射到 `*-XHTTP-TLS`，已修复。
- 发现 full REALITY 协议名未进入 reality 参数解析，导致指定端口被忽略，已修复。
- 发现 `xray del` 删除成功但返回 `1`，并且直连协议会打印误导性的 Nginx `.conf` 删除提示，已修复。
- 修复提交: `82d4a72 fix: align legacy protocol argument handling`。

## 残留风险

- 当前 Certbot renewal 仍是 `authenticator = nginx`；P0 webroot-first 逻辑未在本次 dry-run 中强制迁移现有 renewal。
- `xray client` legacy 不支持 VLESS full client 导出；本次客户端连通性使用手工临时 client JSON。
- Go CLI 对直连协议 `info/url` 的地址仍按 Phase 1 边界显示 `203.0.113.10` 占位，不代表真实公网 IP。
- Nginx 测试存在既有 warning: `ssl_stapling ignored, no OCSP responder URL`，不影响本次配置测试通过。

结论: 真实 VPS 全量验收通过，且验收中暴露的 legacy 参数解析和删除返回码问题已修复、复测通过。
