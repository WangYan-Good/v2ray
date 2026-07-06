# Phase 7 生产替换实施文档

## 目标

Phase 7 的目标是完成生产运行时切换：所有公开 `xray` 命令由 Go CLI 直接处理，不再发布 `code.zip`，同时保留 GitHub Release 和远程一键安装能力。

## 范围

- 保留 `install.sh`，但它只负责下载并校验 Go tarball，然后调用 `/usr/local/bin/xray install`。
- 保留 `tests/*.sh` 作为测试 harness。
- 删除 `xray.sh`、`src/` 和 `internal/legacy`。
- Release assets 固定为 `install.sh`、`xray-linux-amd64.tar.gz`、`xray-linux-arm64.tar.gz`、`checksums.txt`。

## 验收标准

- `git ls-files xray.sh src internal/legacy` 为空。
- 生产代码不引用 `/etc/xray/sh`、`XRAY_LEGACY_BIN` 或 legacy delegate。
- `xray add/change/del/client/mihomo/refresh-sub/sub-url/update/install/uninstall/start/stop/restart/test` 均由 Go 路由识别。
- `bash <(curl -Ls .../install.sh)` 仍是远程一键安装入口。
- `go test ./...`、`bash tests/run.sh`、`bash tests/shellcheck.sh` 通过。
- 真实 VPS 验收通过后，记录到 `docs/09-testing/`。

## 实施步骤

1. 补齐 Go 写入和运维命令，所有系统副作用支持 `--root` 测试根目录。
2. 更新 release workflow 和 `install.sh`，移除 `code.zip`。
3. 删除旧 Bash runtime 和 legacy delegate。
4. 更新测试契约和文档入口。
5. 在 `bak.proxy.yourdie.com` 备份后部署 Go binary，移除远端 `/etc/xray/sh`，执行真实服务和客户端连通性验收。
