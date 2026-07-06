# Legacy 兼容层设计

## 目标

本文档定义 Phase 5 的 Go/Bash 兼容层。目标是允许 Go binary 成为 `/usr/local/bin/xray`，同时让未迁移命令继续通过旧 Bash 实现工作。

状态：本文是历史阶段设计。当前生产边界以 `go-runtime-design.md` 和 Phase 7 为准；Go CLI 不再委托 `/etc/xray/sh/xray.sh`。

## 包结构

```text
internal/legacy/
  commands.go     migrated/legacy/unknown 分类
  delegate.go     legacy runner 接口和 OS runner
  switch_plan.go  Go entry 切换和 rollback plan
```

## 命令分类

### Migrated

Go 已接管：

- `version`、`ver`、`v`
- `status`、`s`
- `info`、`i`
- `url`
- `gen`
- `download-plan`
- `switch-plan`

### Legacy

Bash 继续承载：

- 写入、删除、更新、卸载、服务控制。
- 订阅刷新和前端修复。
- Xray Core passthrough。
- help 和 main menu。

### Unknown

既不属于 Go，也不属于 legacy command 的输入，Go 直接返回 usage error，不委托 Bash。

## Legacy Path

默认路径：

```text
/etc/xray/sh/xray.sh
```

环境变量覆盖：

```text
XRAY_LEGACY_BIN=/path/to/xray.sh
```

Go 不允许把 legacy path 解析为 `/usr/local/bin/xray`，避免递归调用自己。

## 委托行为

输入：

```bash
xray add vws example.com
```

执行：

```bash
/etc/xray/sh/xray.sh add vws example.com
```

要求：

- stdout/stderr 连接到子进程。
- stdin 透传给子进程，保留交互式 Bash 命令。
- 子进程退出码原样返回。
- 委托前输出 warning，例如：

```text
warning: delegating legacy command "add" to /etc/xray/sh/xray.sh
```

## Switch Plan

Go 入口切换计划只描述步骤，不在自动化测试中执行。

Go 模式：

- install Go binary to `/usr/local/bin/xray`
- keep Bash legacy entry at `/etc/xray/sh/xray.sh`
- set rollback command to `ln -sf /etc/xray/sh/xray.sh /usr/local/bin/xray`

Rollback 模式：

- restore `/usr/local/bin/xray` symlink to `/etc/xray/sh/xray.sh`
- keep Go binary release asset available for reinstall

## 安装脚本

官方在线安装路径：

1. 下载 `code.zip`，安装 Bash legacy 文件到 `/etc/xray/sh`。
2. 下载 `xray-linux-{arch}.tar.gz`。
3. 使用 `checksums.txt` 校验 Go tarball。
4. 解压 Go binary。
5. 写入 `/usr/local/bin/xray`。

本地安装模式：

- 若没有 Go tarball，保留 Bash symlink。
- 输出 warning，提示这是本地回退路径。

## 测试策略

Go 单元测试：

- command classification。
- fake legacy runner 参数和退出码。
- switch plan 输出。

Bash 契约测试：

- 用临时 legacy script 验证委托。
- 不触碰真实 `/etc` 和 `/usr/local/bin`。
- 静态检查 `install.sh` 包含 Go asset、checksum 和 fallback。
