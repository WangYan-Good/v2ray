# Phase 1 Go CLI 骨架与只读命令实施文档

## 目标

Phase 1 的目标是在不影响现有 Bash 安装与运行路径的前提下，建立可测试的 Go CLI 骨架，并实现只读命令：

- `version`
- `status`
- `info`
- `url`

这一阶段只验证 Go 对现有配置状态的读取、解析和展示能力。它不写系统文件，不 reload 服务，不调用 Certbot，不替换 `/usr/local/bin/xray`，也不迁移 `add/change/del/update` 等写入路径。

## 依赖基线

Phase 1 启动前必须满足：

- Phase 0 已完成并提交。
- `bash tests/run.sh` 通过。
- `bash tests/shellcheck.sh` 通过。
- `tests/fixtures/xray-conf/*.json` 可作为 Go 读取配置的第一批输入。
- `docs/04-backend/command-matrix.md` 已明确只读命令边界。
- `docs/07-data/protocol-contracts.md` 已明确稳定输出字段。

## 范围

### 必做范围

| 类别 | 内容 | 目的 |
| --- | --- | --- |
| Go module | 新增 `go.mod` 和 `cmd/xray` 入口 | 建立可构建、可测试的 Go 工程骨架。 |
| CLI 路由 | 支持 `version/status/info/url` 及主要别名 | 对齐 Bash 只读命令入口。 |
| 配置读取 | 从配置目录读取 `*.json` inbound 文件 | 复用当前 `/etc/xray/conf` 文件驱动模型。 |
| Fixture 支持 | 支持通过 flag 或环境变量指定 fixture 配置目录 | 确保测试不依赖真实 `/etc`。 |
| 协议解析 | 读取 Phase 0 fixture 中的 VMess、VLESS、Trojan、Shadowsocks、Socks 字段 | 为 Phase 2 协议模型打基础。 |
| URL 输出 | 基于已读配置生成 URL 关键字段 | 验证 Go 对稳定字段的复现能力。 |
| 测试 | 新增 Go 单元测试和 Bash 契约测试 | 将 Phase 1 纳入现有 CI 入口。 |

### 暂不做范围

- 不实现 `add/change/del/fix/update/install/uninstall`。
- 不生成或修改 Xray JSON。
- 不生成 Nginx/Caddy/Certbot 配置。
- 不生成 Mihomo YAML。
- 不调用 Xray API。
- 不读取真实 systemd 状态作为测试依赖。
- 不修改 `install.sh` 的默认安装行为。
- 不把 `/usr/local/bin/xray` 指向 Go 二进制。

## 兼容性边界

### 必须保持兼容

| 边界 | 要求 |
| --- | --- |
| Bash 主线 | 现有 Bash `xray` 命令仍是生产入口。 |
| 文件模型 | Go 默认读取 `/etc/xray/conf`，测试可覆盖为 `tests/fixtures/xray-conf`。 |
| 命令别名 | Go CLI 支持 `version/ver/v`、`status/s`、`info/i`、`url`。 |
| 只读行为 | Phase 1 Go 命令不得写文件、创建目录、删除文件、reload 服务、执行 Certbot。 |
| 输出字段 | `info/url` 必须保留 Phase 0 标记为稳定的字段。 |
| 错误语义 | 找不到配置、JSON 无效、协议暂不支持时必须返回非零退出码和明确错误。 |

### 可以改进但需记录

| 边界 | 可改进方向 | 约束 |
| --- | --- | --- |
| 输出排版 | 可以比 Bash 更简洁、更结构化 | 稳定字段不能丢失。 |
| 颜色输出 | 默认可不实现颜色 | 测试不得依赖颜色。 |
| 配置匹配 | 可先支持精确文件名和大小写不敏感子串匹配 | 多匹配时必须明确报错或列出候选。 |
| `status` | 可先报告 Go 可静态判断的信息 | 不把 systemd 探测作为 Phase 1 测试要求。 |

### 明确禁止

- 禁止 Go Phase 1 修改 `/etc/xray`、`/etc/nginx`、`/etc/caddy`、`/etc/letsencrypt`。
- 禁止 Go Phase 1 在测试中访问公网。
- 禁止 Go Phase 1 默认接管现有 `xray` 命令。
- 禁止为了 Go 实现便利改变 fixture 或 Phase 0 契约。

## CLI 接口

Phase 1 建议二进制名为 `xray-go` 或测试路径 `go run ./cmd/xray`。最终安装名仍待 Phase 5 切换时决定。

### 全局 flag

| Flag | 默认值 | 说明 |
| --- | --- | --- |
| `--conf-dir` | `/etc/xray/conf` | 受管理节点 JSON 目录。测试使用 `tests/fixtures/xray-conf`。 |
| `--config` | `/etc/xray/config.json` | 主配置路径。Phase 1 可只保存为路径，不强制解析。 |
| `--no-color` | `true` | Phase 1 默认无颜色输出。 |

### 命令

| 命令 | 别名 | 行为 |
| --- | --- | --- |
| `version` | `ver`, `v` | 输出 Go CLI 版本、构建信息占位、配置目录。不得读取网络。 |
| `status` | `s` | 输出配置目录是否存在、可读配置数量、主配置路径是否存在。不得调用 systemd。 |
| `info [name]` | `i` | 读取匹配配置，输出协议、地址、端口、UUID/密码、network、host/path、TLS/REALITY 字段。 |
| `url [name]` | 无 | 读取匹配配置，输出分享 URL。Phase 1 至少覆盖 Phase 0 fixture 支持的协议。 |

## 数据模型

Phase 1 只需要表达读取所需字段，不需要完整 Xray schema。

建议模型：

```text
Node
  Name
  FileName
  Protocol
  Port
  Listen
  UserID
  Password
  Method
  Network
  Security
  Host
  Path
  ServiceName
  Flow
  ServerName
  Fingerprint
  PublicKey
```

解析规则：

- `Name` 默认来自文件名去掉 `.json`。
- `Address` 选择：
  - TLS 前端协议优先使用 `Host`。
  - REALITY 和直连协议在 fixture 测试中使用固定占位地址 `203.0.113.10`，真实环境可提示需要显式地址或后续实现 IP 探测。
- `Path`：
  - WS/XHTTP 使用以 `/` 开头的 path。
  - gRPC 使用 `serviceName`，URL 参数名为 `serviceName`。
- REALITY：
  - `ServerName` 来自 `realitySettings.serverNames[0]`。
  - `PublicKey` 来自 `realitySettings.publicKey`。
  - `Fingerprint` Phase 1 固定为 `ios`，与 Bash 当前输出一致。

## 验收标准

### 文档验收

- `docs/04-backend/go-module-design.md` 完成，描述包结构、只读边界和测试策略。
- `go-refactor-plan.md` 的 Phase 1 链接到本文档。
- `docs/README.md` 的关键文档入口包含 Phase 1 文档和 Go module 设计文档。

### 工程验收

- 仓库根目录新增 `go.mod`。
- `go test ./...` 通过。
- `go run ./cmd/xray version` 可执行。
- `go run ./cmd/xray --conf-dir tests/fixtures/xray-conf status` 可输出可读配置数量。
- `go run ./cmd/xray --conf-dir tests/fixtures/xray-conf info vless-reality` 输出 REALITY 稳定字段。
- `go run ./cmd/xray --conf-dir tests/fixtures/xray-conf url vless-xhttp` 输出 `vless://` 且包含 `type=xhttp`、`security=tls`、`path`。

### 契约测试验收

- 新增 `tests/testcase-11-go-cli-readonly.sh`，由 `tests/run.sh` 自动发现。
- `testcase-11` 不访问真实 `/etc`，只使用 fixture。
- `testcase-11` 至少断言：
  - Go module 存在。
  - `go test ./...` 通过。
  - `version/status/info/url` 可运行。
  - `info/url` 包含 REALITY、WS、gRPC、XHTTP、Shadowsocks、Socks 的关键字段。
- 原有 `tests/testcase-01` 到 `testcase-10` 继续通过。

### 安全验收

- Phase 1 Go 代码中不得调用写入 API，例如 `os.WriteFile`、`os.MkdirAll`、`os.Remove`，除测试临时目录外。
- Phase 1 Go 代码中不得执行外部命令，例如 `systemctl`、`certbot`、`nginx`、`xray`。
- Phase 1 Go 测试不得依赖公网。

## 实施步骤

### Step 1: Go 工程骨架

1. 新增 `go.mod`，module 建议为 `github.com/WangYan-Good/xray`。
2. 新增 `cmd/xray/main.go`，只做参数解析和命令分发。
3. 新增内部包：
   - `internal/app`
   - `internal/config`
   - `internal/protocol`
   - `internal/ui`
4. `main.go` 调用 `app.Run(args, stdout, stderr)`，方便测试。

完成条件：`go test ./...` 和 `go run ./cmd/xray version` 可运行。

### Step 2: 配置读取

1. 在 `internal/config` 中实现目录扫描。
2. 忽略非 `.json` 文件和 `*-link.json` 动态端口辅助文件。
3. JSON 只解析 `.inbounds[0]`。
4. 文件匹配规则：
   - 无 name 且只有一个配置：选择该配置。
   - 有 name：大小写不敏感匹配文件名或去后缀名称。
   - 多匹配：返回错误并列候选。
   - 无匹配：返回错误。

完成条件：fixture 目录可被 Go 测试读出 8 个主配置。

### Step 3: 只读命令

1. `version` 输出 Go CLI 名称和版本占位，例如 `xray go-cli dev`。
2. `status` 输出配置目录、主配置路径、节点数量。
3. `info` 输出稳定字段，格式可采用 `key = value`。
4. `url` 输出分享 URL。

完成条件：所有命令在 fixture 上有测试覆盖。

### Step 4: URL 生成

1. VMess：生成 `vmess://` base64 JSON，包含 `v/add/port/id/aid/net/type/host/path/tls`。
2. VLESS：生成 `vless://`，支持 TLS、REALITY、WS、gRPC、XHTTP。
3. Trojan：生成 `trojan://`，支持 XHTTP fixture 的基础 URL。
4. Shadowsocks：生成 `ss://method:password@server:port#name` 的兼容格式。
5. Socks：生成 `socks://base64(user:pass)@server:port#name`。

完成条件：URL 测试只断言 scheme 和关键 query 字段，不依赖参数顺序。

### Step 5: 测试接入

1. 新增 Go 单元测试覆盖 parser 和 URL builder。
2. 新增 `tests/testcase-11-go-cli-readonly.sh`。
3. 如 CI 环境没有 Go，需要在 `.github/workflows/ci.yml` 加 `setup-go`；如果已有系统 Go，则无需修改。

完成条件：`bash tests/run.sh`、`go test ./...` 均通过。

## 任务拆分建议

| ID | 任务 | 产物 | 优先级 |
| --- | --- | --- | --- |
| P1-01 | Phase 1 文档与模块设计 | 本文档、`docs/04-backend/go-module-design.md` | P0 |
| P1-02 | Go module 骨架 | `go.mod`、`cmd/xray/main.go` | P0 |
| P1-03 | 配置读取与匹配 | `internal/config` | P0 |
| P1-04 | 节点模型与协议字段提取 | `internal/protocol` 或 `internal/config` | P0 |
| P1-05 | `version/status` | `internal/app` | P0 |
| P1-06 | `info` | `internal/app`、`internal/ui` | P0 |
| P1-07 | `url` | `internal/protocol` | P0 |
| P1-08 | Go 单元测试 | `*_test.go` | P0 |
| P1-09 | Bash 契约测试 | `tests/testcase-11-go-cli-readonly.sh` | P0 |
| P1-10 | Phase 1 验收检查 | `go test ./...`、`bash tests/run.sh`、ShellCheck | P0 |

## 完成定义

Phase 1 完成时，应能用一句话描述：

Go CLI 已能在 fixture 和真实只读配置目录上读取现有 Xray 节点，输出 `version/status/info/url` 的稳定字段与分享 URL，并且整个过程不会写入系统状态、不会影响 Bash 主线安装和运行。
