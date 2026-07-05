# Phase 5 命令切换与兼容层实施文档

## 目标

Phase 5 的目标是让 Go CLI 成为默认用户入口，同时保留旧 Bash 主线作为未迁移命令的兼容层。

这一阶段不删除 Bash 实现。Go 负责已迁移命令的主路径；未迁移命令通过固定 legacy path 委托到 `/etc/xray/sh/xray.sh`。安装脚本在官方在线安装路径中安装 Go binary 到 `/usr/local/bin/xray`，并保留 `/etc/xray/sh/xray.sh` 作为回退入口。本地安装模式可继续使用 Bash 入口。

## 依赖基线

Phase 5 启动前必须满足：

- Phase 0 到 Phase 4 已完成并提交。
- Release workflow 已生成 `xray-linux-amd64.tar.gz`、`xray-linux-arm64.tar.gz` 和 `checksums.txt`。
- Go CLI 已具备只读命令、配置生成、前端模板和下载计划。
- Bash `xray.sh` 仍可作为 legacy 入口运行。
- `bash tests/run.sh` 与 `bash tests/shellcheck.sh` 通过。

## 范围

### 必做范围

| 类别 | 内容 | 目的 |
| --- | --- | --- |
| 兼容层 | 新增 `internal/legacy`，维护已迁移/未迁移命令矩阵 | 避免 Go 对未迁移命令直接报 unknown。 |
| 委托执行 | 未迁移命令委托到 Bash legacy entry | 保持 `add/change/del/update/uninstall` 等仍可用。 |
| 迁移提示 | 委托前输出 warning，说明正在走 Bash 兼容路径 | 让用户知道命令尚未迁移。 |
| 明确错误 | legacy path 缺失时返回明确错误和修复提示 | 避免静默失败。 |
| 切换计划 | 新增 `switch-plan` 只读命令，输出 Go 入口、legacy 路径和 rollback 步骤 | 固定安装/回滚合同。 |
| 安装脚本 | 官方在线安装下载 Go CLI tarball，并把 `/usr/local/bin/xray` 安装为 Go binary | 让默认入口切换到 Go。 |
| 回退路径 | 保留 `/etc/xray/sh/xray.sh`，文档化 rollback symlink | 确保预览版本可回退。 |
| 测试 | 新增 Go 单元测试和 Bash 契约测试 | 将 Phase 5 纳入 `tests/run.sh`。 |

### 暂不做范围

- 不删除 Bash `src/` 逻辑。
- 不把所有写入命令迁移到 Go。
- 不在自动化测试中执行真实 `/usr/local/bin/xray` 覆盖、systemd 或 `/etc` 写入。
- 不改变 Xray Core systemd 运行方式。
- 不移除 `code.zip`、`install.sh` 或 `xray.sh` release asset。

## 兼容性边界

### Go 主路径命令

Go 直接执行：

- `version` / `ver` / `v`
- `status` / `s`
- `info` / `i`
- `url`
- `gen`
- `download-plan`
- `switch-plan`

### Legacy 委托命令

以下命令继续委托 Bash：

- 写入/管理：`add`、`a`、`change`、`c`、`config`、`del`、`d`、`rm`、`ddel`、`dd`。
- 修复：`fix`、`fix-all`、`fix-config.json`、`fix-caddyfile`、`fix-nginxfile`。
- 订阅：`mihomo`、`clash`、`refresh-sub`、`sub-refresh`、`sub-url`。
- 更新/安装：`update`、`u`、`up`、`U`、`update.sh`、`reinstall`、`uninstall`、`un`。
- 服务/诊断：`start`、`stop`、`restart`、`r`、`test`、`t`、`log`、`logerr`、`errlog`、`dns`、`bbr`、`ip`、`get-port`、`debug`。
- passthrough/help：`api`、`xapi`、`bin`、`run`、`uuid`、`tls`、`convert`、`client`、`genc`、`qr`、`help`、`h`、`--help`、`main`。

### 明确禁止

- 禁止 Go 委托到 `/usr/local/bin/xray`，避免递归调用自己。
- 禁止 legacy path 不存在时静默吞掉命令。
- 禁止自动化测试覆盖真实 `/usr/local/bin/xray`。
- 禁止 Phase 5 删除旧 Bash 入口。

## CLI 接口

### Legacy 委托

```bash
xray add vws example.com
```

当 `xray` 是 Go binary 时：

1. Go 识别 `add` 是 legacy command。
2. stderr 输出兼容提示。
3. 执行 `/etc/xray/sh/xray.sh add vws example.com`。
4. 返回 Bash 进程退出码。

可通过环境变量覆盖 legacy path：

```bash
XRAY_LEGACY_BIN=/custom/xray.sh xray add ...
```

### Switch Plan

```bash
xray switch-plan
xray switch-plan --mode rollback
```

输出稳定 `key = value` 文本，包含：

- entry path: `/usr/local/bin/xray`
- Go binary source/target
- legacy path: `/etc/xray/sh/xray.sh`
- rollback command
- install steps

## 数据模型

```text
legacy.Command
  Name
  Migrated
  Legacy

legacy.SwitchPlan
  Mode
  EntryPath
  LegacyPath
  GoTarget
  RollbackCommand
  Steps[]
```

## 验收标准

### 文档验收

- 新增本文档，并在 `go-refactor-plan.md` 的 Phase 5 段落中链接。
- 新增 `docs/04-backend/legacy-compatibility-design.md`，描述命令分类、委托、安装切换和回滚。
- `docs/README.md` 的关键文档入口包含 Phase 5 文档和 legacy 兼容设计文档。

### 工程验收

- `internal/legacy` 能区分 migrated、legacy、unknown command。
- Go 未迁移命令会委托到 `XRAY_LEGACY_BIN` 或默认 `/etc/xray/sh/xray.sh`。
- 委托时 stderr 包含兼容提示。
- legacy 子进程退出码会透传给 Go CLI。
- legacy path 缺失时返回非零退出码和明确错误。
- `switch-plan` 输出 Go 默认入口和 rollback 步骤。
- `install.sh` 下载 Go CLI tarball，校验 checksums，并把 `/usr/local/bin/xray` 安装为 Go binary；本地安装路径可保留 Bash 入口。

### 契约测试验收

- 新增 `tests/testcase-15-go-legacy-switch.sh`，由 `tests/run.sh` 自动发现。
- `testcase-15` 不写真实 `/usr/local/bin/xray`，不访问公网，不调用 systemd。
- `testcase-15` 至少断言：
  - `go test ./...` 通过。
  - fixture legacy script 可接收 `add` 参数并返回输出。
  - legacy exit code 会透传。
  - unknown command 不会被错误委托。
  - `switch-plan` 包含 Go entry、legacy path、rollback。
  - `install.sh` 静态包含 Go asset 下载、checksum 校验、Go entry 安装和 legacy fallback。
- 原有 `testcase-01` 到 `testcase-14` 继续通过。

## 实施步骤

### Step 1: 文档与兼容设计

1. 新增本文档和 `legacy-compatibility-design.md`。
2. 更新 `go-refactor-plan.md`、`docs/README.md`、release guide。

完成条件：Phase 5 的命令分类和回滚边界清晰。

### Step 2: Legacy 包

1. 新增 `internal/legacy`。
2. 实现 command classification。
3. 实现 OS runner 和 fake runner 可测接口。
4. 实现 switch plan 输出。

完成条件：Go 单元测试覆盖 migrated、legacy、unknown、exit code。

### Step 3: App 接入

1. Go 未识别命令先查 legacy command。
2. legacy command 存在时委托 Bash。
3. legacy path 缺失时输出明确错误。
4. 新增 `switch-plan` 命令。

完成条件：app 测试覆盖委托、错误和 switch plan。

### Step 4: 安装脚本切换

1. 增加 Go CLI asset 下载。
2. 校验 `checksums.txt`。
3. 默认把 `/usr/local/bin/xray` 安装为 Go binary。
4. 保留 `/etc/xray/sh/xray.sh`。
5. 本地安装无法获得 Go asset 时保留 Bash 入口。

完成条件：Bash syntax、ShellCheck 和静态契约测试通过。

### Step 5: 验收和提交

1. 新增 `tests/testcase-15-go-legacy-switch.sh`。
2. 运行 `bash tests/run.sh`。
3. 运行 `bash tests/shellcheck.sh`。
4. 提交 Phase 5 commit。

## 完成定义

Phase 5 完成时，应能用一句话描述：

`/usr/local/bin/xray` 已可作为 Go CLI 默认入口，Go 已迁移命令直接运行，未迁移命令通过明确的 Bash legacy path 委托并保留回滚路径，用户在预览版本中可以安全切换和撤回。
