# Phase 6 Bash 旧实现清理实施文档

## 目标

Phase 6 的目标是清理已经由 Go 接管的 Bash 入口逻辑，并把项目文档切换为 Go CLI 主线视角。

本阶段不删除仍被 legacy 兼容层依赖的 Bash 写入/管理逻辑。`add/change/del/update/uninstall/refresh-sub/fix-*` 等命令仍保留在 Bash 中，由 Go legacy 层委托执行。清理重点是避免已迁移命令在 Bash 主路由中继续承载业务入口，降低双实现漂移风险。

## 依赖基线

Phase 6 启动前必须满足：

- Phase 0 到 Phase 5 已完成并提交。
- `/usr/local/bin/xray` 默认入口已可安装为 Go binary。
- Go CLI 已接管 `version/status/info/url/gen/download-plan/switch-plan`。
- Legacy 委托层能把未迁移命令转发到 `/etc/xray/sh/xray.sh`。
- `bash tests/run.sh` 与 `bash tests/shellcheck.sh` 通过。

## 范围

### 必做范围

| 类别 | 内容 | 目的 |
| --- | --- | --- |
| Bash 路由清理 | 从 Bash `main()` 中移除或阻断 Go 已迁移命令的业务执行入口 | 防止同一命令继续存在两套主实现。 |
| Legacy 保留 | 保留未迁移命令的 Bash 路由和函数 | 保证 Phase 5 兼容层仍可用。 |
| 明确提示 | 直接调用 Bash 已迁移命令时提示使用 Go CLI | 避免用户误以为 Bash 仍是主入口。 |
| 文档切换 | 更新文档，说明 Go CLI 为主、Bash 为 legacy/fallback | 让维护者按新架构工作。 |
| 契约测试 | 新增/更新测试证明已迁移命令不再依赖 Bash 主路由 | 防止回退到双主线。 |

### 暂不做范围

- 不删除 `src/core.sh`、`src/nginx.sh`、`src/caddy.sh`、`src/mihomo.sh`。
- 不删除 Bash `add/change/del/update/uninstall` 等未迁移函数。
- 不移除 `code.zip`、`install.sh`、`xray.sh` release asset。
- 不要求 Bash rollback 入口完整覆盖 Go 已迁移命令；rollback 是应急恢复 legacy 管理路径。
- 不执行真实 `/usr/local/bin/xray` 覆盖或系统服务操作。

## 兼容性边界

### Go 已迁移命令

以下命令不得继续由 Bash `main()` 执行业务逻辑：

- `version` / `ver` / `v`
- `status` / `s`
- `info` / `i`
- `url`
- `gen`
- `download-plan`
- `switch-plan`

### Bash 仍保留命令

以下命令继续由 Bash legacy 承载：

- `add/change/del/update/uninstall`
- `mihomo/refresh-sub/sub-url`
- `fix-*`
- `start/stop/restart/test/log/dns/bbr`
- Xray Core passthrough 和交互式 `main`

### 明确禁止

- 禁止删除 legacy 兼容层仍会委托的 Bash 命令。
- 禁止 release workflow 移除 Bash 资产。
- 禁止 Bash 已迁移命令静默继续执行旧业务逻辑。

## 验收标准

### 文档验收

- 新增本文档，并在 `go-refactor-plan.md` 的 Phase 6 段落中链接。
- 新增 `docs/04-backend/bash-cleanup-design.md`，描述 Bash 保留/清理清单。
- `docs/README.md` 的关键文档入口包含 Phase 6 文档和 Bash cleanup 设计。
- 产品/架构文档中的入口说明改为 Go CLI 主线、Bash legacy 兼容层。

### 工程验收

- `src/core.sh main()` 中 `version/status/info/url/gen` 业务分支被移除或替换为明确迁移提示。
- `url | qr` 拆分后，`url` 走迁移提示，`qr` 仍留给 Bash。
- `a | add | gen | no-auto-tls` 拆分后，`gen` 不再调用 Bash `add`。
- Legacy 命令矩阵仍包含未迁移命令。
- Release workflow 仍上传 `code.zip`、`install.sh`、Go CLI tarball 和 `checksums.txt`。

### 契约测试验收

- 新增 `tests/testcase-16-bash-cleanup.sh`，由 `tests/run.sh` 自动发现。
- `testcase-16` 至少断言：
  - Go migrated commands 在 `internal/legacy/commands.go` 的 migrated set 中。
  - Bash `src/core.sh` 对 `version/status/info/url/gen` 输出迁移提示，不再调用旧业务函数。
  - Bash legacy routes 仍保留 `add/change/del/update/uninstall/mihomo/refresh-sub/sub-url/fix-*`。
  - Release assets 仍完整。
- 原有 `testcase-01` 到 `testcase-15` 继续通过。

## 实施步骤

### Step 1: 文档和清理清单

1. 新增本文档和 `bash-cleanup-design.md`。
2. 更新 `go-refactor-plan.md`、`docs/README.md` 和架构/发布说明。

完成条件：维护者能明确哪些 Bash 可清理、哪些必须保留。

### Step 2: Bash migrated route 清理

1. 在 `src/core.sh` 中新增迁移提示 helper。
2. 将 `gen` 从 `add` 分支拆出。
3. 将 `info/url/status/version` 改为迁移提示。
4. 保留 `qr`、`add`、`mihomo` 等 legacy 分支。

完成条件：Bash 不再承载 Go 已迁移命令的业务主入口。

### Step 3: 测试更新

1. 更新命令矩阵测试，区分 Go migrated 和 Bash legacy routes。
2. 新增 `testcase-16-bash-cleanup.sh`。
3. 运行完整测试和 ShellCheck。

完成条件：`bash tests/run.sh`、`bash tests/shellcheck.sh` 均通过。

## 完成定义

Phase 6 完成时，应能用一句话描述：

Go CLI 已成为项目主入口；Bash 只保留未迁移命令的 legacy 兼容和故障恢复路径，已迁移命令不再由 Bash 主路由承载业务逻辑，文档、测试和发布资产均反映这一架构。
