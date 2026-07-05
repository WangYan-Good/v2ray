# Bash 清理设计

## 目标

本文档定义 Phase 6 的 Bash 清理边界。清理不是删除全部 Bash，而是删除已经由 Go 接管命令在 Bash 主入口中的业务路由。

## Go 主线

Go CLI 是默认入口：

```text
/usr/local/bin/xray -> Go binary
```

Go 已接管：

- `version/ver/v`
- `status/s`
- `info/i`
- `url`
- `gen`
- `download-plan`
- `switch-plan`

这些命令的测试、输出和错误码以后以 Go 实现为准。

## Bash Legacy

Bash legacy 入口仍保留：

```text
/etc/xray/sh/xray.sh
```

Go legacy 层会把未迁移命令委托到该文件：

- 写入：`add/change/del/ddel`
- 订阅：`mihomo/refresh-sub/sub-url`
- 修复：`fix/fix-all/fix-config.json/fix-caddyfile/fix-nginxfile`
- 更新/卸载：`update/reinstall/uninstall`
- 服务：`start/stop/restart/test`
- 诊断和 passthrough：`log/dns/bbr/api/bin/run/help/main`

## Bash Migrated Route 行为

直接调用 Bash 入口的已迁移命令时，应输出明确错误：

```text
命令 (version) 已迁移到 Go CLI，请使用: /usr/local/bin/xray version
```

这样可以避免双主线漂移，同时不影响 Go 默认入口。

## Release 资产

Phase 6 后仍保留：

- `code.zip`
- `install.sh`
- `xray-linux-amd64.tar.gz`
- `xray-linux-arm64.tar.gz`
- `checksums.txt`

删除 Bash release asset 必须等 Phase 6 之后另行规划，且需要确认所有 legacy 命令已经迁移或废弃。
