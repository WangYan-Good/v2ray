# Phase 2 协议模型与配置生成实施文档

## 目标

Phase 2 的目标是把 Phase 1 的“读取现有配置”推进到“用 Go 的结构化协议模型生成可验证产物”。

本阶段继续保持无系统副作用：Go 代码可以生成 Xray JSON、分享 URL、客户端 outbound JSON 和 Mihomo 节点预览，但不得写入 `/etc/xray`，不得修改 Nginx/Caddy/Certbot 配置，不 reload 服务，也不接管 Bash 的 `add/change/del` 主线。

## 依赖基线

Phase 2 启动前必须满足：

- Phase 0 和 Phase 1 已完成并提交。
- `docs/07-data/protocol-contracts.md` 已固定协议字段契约。
- `tests/fixtures/xray-conf/*.json` 可作为生成结果的字段对照基线。
- Phase 1 Go CLI 已能读取 fixture，并能生成 `info/url` 输出。
- `bash tests/run.sh` 与 `bash tests/shellcheck.sh` 通过。

## 范围

### 必做范围

| 类别 | 内容 | 目的 |
| --- | --- | --- |
| 协议 Profile | 新增强类型协议配置档，覆盖固定测试值和用户输入所需字段 | 避免继续用松散 map 拼装协议。 |
| Xray JSON 生成 | 生成 server inbound JSON，覆盖 REALITY、WS、gRPC、XHTTP、TCP、SS、Socks | 为后续 `add` 迁移打基础。 |
| URL 复用 | 生成结果能复用 Phase 1 `ShareURL` 逻辑 | 保证读取路径和生成路径共享协议语义。 |
| 客户端 JSON | 生成最小 outbound/client JSON 预览 | 为后续客户端导出和订阅做准备。 |
| Mihomo 节点 | 生成单节点 YAML 片段和订阅预览 | 为 Phase 3/订阅迁移建立模型。 |
| CLI 预览 | 新增只读 `gen` 预览命令，输出到 stdout | 让契约测试无需写系统文件即可验证生成能力。 |
| 测试 | 新增 Go 单元测试和 Bash 契约测试 | 将 Phase 2 纳入现有 `tests/run.sh`。 |

### 暂不做范围

- 不实现 Bash `add/change/del` 写入路径迁移。
- 不把生成结果写入 `/etc/xray/conf`。
- 不生成 Nginx/Caddy 配置。
- 不调用 `xray test` 作为 CI 必需项；若本地有 Xray Core，可作为手动补充验收。
- 不做交互式 prompt。
- 不实现完整 Mihomo 配置管理、token 写入或订阅路由 reload。
- 不支持 Trojan XHTTP 的 Mihomo 节点生成；必须保留显式 skip。

## 兼容性边界

### 必须保持兼容

| 边界 | 要求 |
| --- | --- |
| 固定字段 | 使用 `docs/07-data/protocol-contracts.md` 的固定测试值作为默认 Profile。 |
| 监听语义 | TLS 前端协议监听 `127.0.0.1`，REALITY/VMess/SS/Socks 直连监听 `0.0.0.0`。 |
| REALITY | 保留 `flow=xtls-rprx-vision`、`serverName`、`publicKey/privateKey`、`fingerprint=ios`。 |
| XHTTP | 默认 `mode=auto`，path 保持 `/xray-test`。 |
| VMess TCP | `header.type=none` 作为 Phase 2 支持边界。 |
| Mihomo | VLESS REALITY、VLESS XHTTP、Shadowsocks、Socks 必须生成；Trojan XHTTP 必须输出 skip 原因。 |
| 只读行为 | `gen` 只输出 stdout，不写文件、不调用外部命令。 |

### 可以改进但需记录

| 边界 | 可改进方向 | 约束 |
| --- | --- | --- |
| JSON 排版 | 可采用稳定缩进，不要求与 Bash 字节级一致 | 关键字段必须等价。 |
| 参数顺序 | URL query 和 YAML 字段顺序可以由 Go 稳定实现决定 | 测试只断言关键字段。 |
| Profile 来源 | Phase 2 可先提供 fixture preset 和纯函数 API | Phase 3/后续再接入真实交互输入。 |

### 明确禁止

- 禁止 Phase 2 Go production 代码调用 `os.WriteFile`、`os.MkdirAll`、`os.Remove`、`os.Rename`。
- 禁止 Phase 2 Go production 代码调用 `exec.Command`、`systemctl`、`certbot`、`nginx`、`xray`。
- 禁止为了生成方便修改 Phase 0 fixture 的兼容字段。
- 禁止让 `gen` 成为默认安装入口或替代 Bash `add`。

## CLI 接口

Phase 2 新增只读预览命令：

```bash
go run ./cmd/xray gen [--format xray|client|mihomo] [profile]
```

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `--format` | `xray` | 输出 Xray inbound JSON、客户端 outbound JSON 或 Mihomo YAML。 |
| `profile` | 无 | `vless-reality`、`vless-ws-tls`、`vless-grpc-tls`、`vless-xhttp-tls`、`trojan-xhttp-tls`、`vmess-tcp`、`shadowsocks`、`socks`。 |

规则：

- `gen --format xray <profile>` 输出单个 server inbound JSON。
- `gen --format client <profile>` 输出单个 client outbound JSON。
- `gen --format mihomo` 输出默认支持节点的 Mihomo 订阅预览，并包含 unsupported skip 注释。
- `gen --format mihomo <profile>` 输出单节点 Mihomo YAML；不支持时返回协议不支持退出码。

## 数据模型

Phase 2 新增 `protocol.Profile`，作为生成路径的输入模型。

```text
Profile
  Key
  Name
  Protocol
  Port
  Listen
  ID
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
  PrivateKey
  HeaderType
  XHTTPMode
```

`Key` 是 CLI 和测试使用的稳定 profile 名称，例如 `vless-reality`；`Name` 是生成产物中的节点展示名，例如 `VLESS-XTLS-uTLS-REALITY-10001`。

Profile 可以转换为 Phase 1 的 `config.Node`，从而复用 URL 和 info 输出逻辑。

## 验收标准

### 文档验收

- 新增本文档，并在 `go-refactor-plan.md` 的 Phase 2 段落中链接。
- 新增 `docs/04-backend/protocol-model-design.md`，描述 Profile、Xray JSON、client JSON、Mihomo 生成边界。
- `docs/README.md` 的关键文档入口包含 Phase 2 文档和协议模型设计文档。

### 工程验收

- `internal/protocol` 提供强类型 Profile 和生成函数。
- 8 个 Phase 0 协议 fixture 都有对应 Profile。
- `gen --format xray vless-reality` 输出 JSON，且包含 `security=reality`、`network=tcp`、`flow=xtls-rprx-vision`。
- `gen --format xray vless-xhttp-tls` 输出 JSON，且包含 `network=xhttp`、`xhttpSettings.mode=auto`、`path=/xray-test`。
- `gen --format client shadowsocks` 输出客户端 outbound JSON，且包含 method/password/server/port。
- `gen --format mihomo` 输出 VLESS REALITY、VLESS XHTTP、Shadowsocks、Socks，并包含 Trojan XHTTP skip 注释。

### 契约测试验收

- 新增 `tests/testcase-12-go-protocol-generation.sh`，由 `tests/run.sh` 自动发现。
- `testcase-12` 不访问真实 `/etc`，不访问公网，不调用 Xray Core。
- `testcase-12` 至少断言：
  - `go test ./...` 通过。
  - Xray JSON 生成结果可被 `jq .` 解析。
  - 生成 JSON 与 fixture 在 protocol、port、listen、network、security、path/serviceName、REALITY 字段上等价。
  - Mihomo 输出包含支持节点和 unsupported skip 注释。
- 原有 `testcase-01` 到 `testcase-11` 继续通过。

### 安全验收

- Phase 2 production Go 代码仍不得写系统文件。
- Phase 2 production Go 代码仍不得执行外部命令。
- 自动化测试不得依赖真实 `/etc`、systemd、Certbot、Nginx、Xray Core、GitHub 或 Let's Encrypt。

## 实施步骤

### Step 1: 协议 Profile

1. 在 `internal/protocol` 中新增 Profile 类型。
2. 建立 8 个 fixture preset。
3. 提供 `ProfileByName`、`DefaultProfiles`、`Node` 转换函数。

完成条件：Go 测试能按名称取到所有 Phase 0 Profile。

### Step 2: Xray JSON 生成

1. 使用 struct/map 组合生成最小 server inbound JSON。
2. 覆盖 VLESS、Trojan、VMess、Shadowsocks、Socks。
3. 为 network 分支生成对应 `streamSettings`。

完成条件：生成 JSON 可被 `jq .` 和 Go `encoding/json` 解析，关键字段与 fixture 等价。

### Step 3: 客户端 JSON 生成

1. 生成最小 outbound JSON。
2. 保留 server、port、id/password、method、network/security 关键字段。
3. 不追求完整客户端模板，只固定 Phase 2 兼容字段。

完成条件：每个支持协议都有客户端 JSON 测试覆盖。

### Step 4: Mihomo 节点生成

1. 生成 VLESS REALITY、VLESS WS、VLESS gRPC、VLESS XHTTP、VMess TCP、Shadowsocks、Socks 节点。
2. Trojan XHTTP 返回 unsupported，并附带 skip reason。
3. 输出订阅预览时包含 `proxy-groups` 和基础 `rules`。

完成条件：Mihomo 测试覆盖支持节点、skip 注释和 proxy group。

### Step 5: CLI 和契约测试

1. 在 `internal/app` 中接入只读 `gen` 命令。
2. 新增 `tests/testcase-12-go-protocol-generation.sh`。
3. 复用 testcase-11 的 Go 容器运行方式，并默认优先国内镜像源。

完成条件：`bash tests/run.sh`、`bash tests/shellcheck.sh` 均通过。

## 任务拆分建议

| ID | 任务 | 产物 | 优先级 |
| --- | --- | --- | --- |
| P2-01 | Phase 2 文档与模型设计 | 本文档、`docs/04-backend/protocol-model-design.md` | P0 |
| P2-02 | Profile preset | `internal/protocol/profile.go` | P0 |
| P2-03 | Xray JSON 生成 | `internal/protocol/xray_json.go` | P0 |
| P2-04 | Client JSON 生成 | `internal/protocol/client_json.go` | P1 |
| P2-05 | Mihomo 节点生成 | `internal/subscription` 或 `internal/protocol` | P0 |
| P2-06 | `gen` 预览命令 | `internal/app` | P0 |
| P2-07 | Go 单元测试 | `*_test.go` | P0 |
| P2-08 | Bash 契约测试 | `tests/testcase-12-go-protocol-generation.sh` | P0 |
| P2-09 | Phase 2 验收检查 | `go test ./...`、`bash tests/run.sh`、ShellCheck | P0 |

## 完成定义

Phase 2 完成时，应能用一句话描述：

Go 已具备协议 Profile 到 Xray JSON、客户端 JSON、分享 URL 和 Mihomo 节点的无副作用生成能力，且生成结果在关键字段上与 Phase 0 fixture 契约等价，可作为后续 `add`、订阅和前端模板迁移的稳定输入。
