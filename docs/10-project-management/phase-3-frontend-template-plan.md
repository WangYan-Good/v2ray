# Phase 3 Nginx/Caddy 模板化实施文档

## 目标

Phase 3 的目标是把 TLS 前端配置从 Bash 字符串拼接推进到可测试的 Go 模板层。

本阶段生成和验证 Nginx/Caddy 配置片段、同域名追加规则、路径冲突检测、include/import 修复、Certbot renewal webroot 模型和配置测试/reload 操作计划。自动化测试仍不写真实 `/etc`，不执行 systemd、Nginx、Caddy 或 Certbot。

## 依赖基线

Phase 3 启动前必须满足：

- Phase 0、Phase 1、Phase 2 已完成并提交。
- `tests/fixtures/nginx/` 和 `tests/fixtures/caddy/` 已固定 `.conf + .add` 模型。
- `tests/fixtures/certbot/` 已固定 webroot/standalone renewal 样例。
- `internal/protocol.Profile` 已能表达 WS、gRPC、XHTTP、Trojan XHTTP 等 TLS 前端协议。
- `bash tests/run.sh` 与 `bash tests/shellcheck.sh` 通过。

## 范围

### 必做范围

| 类别 | 内容 | 目的 |
| --- | --- | --- |
| Nginx 模板 | 生成完整站点 `.conf` 和追加 `.conf.add` location 片段 | 替代 Bash 中高风险 heredoc 拼接。 |
| Caddy 模板 | 生成完整站点 `.conf` 和追加 `.conf.add` reverse_proxy 片段 | 对齐 Caddy 的同域名多协议模型。 |
| 共存模型 | 保留 `.conf + .add`，已有主站点时只生成追加片段 | 避免同域名新增协议覆盖主配置。 |
| 冲突检测 | 检测同 path 不同 upstream port 的冲突 | 阻止多协议互相覆盖路径。 |
| include/import 修复 | 为缺少 `.add` 导入的主配置生成修复后的文本 | 支持从旧配置平滑迁移。 |
| Certbot 模型 | 解析 renewal，识别 standalone/webroot，并生成 webroot 修复结果 | 保持 Nginx 模式 webroot-first。 |
| 操作计划 | 输出 `nginx -t`、reload、`certbot renew --dry-run` 等命令计划 | 固定高副作用动作的顺序和边界。 |
| CLI 预览 | 扩展 `gen --format nginx|nginx-add|caddy|caddy-add` | 让模板输出进入契约测试。 |
| 测试 | 新增 Go 单元测试和 Bash 契约测试 | 将 Phase 3 纳入 `tests/run.sh`。 |

### 暂不做范围

- 不把 Go 生成结果写入 `/etc/nginx` 或 `/etc/caddy`。
- 不执行真实 `nginx -t`、`caddy validate`、`systemctl reload`、`certbot`。
- 不迁移 Bash `add/change/del/fix-nginxfile/fix-caddyfile` 的真实写入路径。
- 不处理用户自定义复杂 Nginx/Caddy 语法的完整 AST；Phase 3 只覆盖当前 fixture 和 Bash 管理模型。
- 不把 `/usr/local/bin/xray` 切到 Go。

## 兼容性边界

### 必须保持兼容

| 边界 | 要求 |
| --- | --- |
| 文件模型 | Nginx 使用 `/etc/nginx/xray/{domain}.conf` 和 `{domain}.conf.add`；Caddy 使用 `/etc/caddy/WangYan-Good/{domain}.conf` 和 `.add`。 |
| TLS 前端 | WS/XHTTP/Trojan XHTTP 使用 HTTP reverse proxy；gRPC 使用 h2c/grpc upstream。 |
| ACME webroot | Nginx 完整站点必须包含 `/.well-known/acme-challenge/` 的 `/var/www/certbot` root。 |
| include/import | 完整站点必须导入 `.add` 文件；缺失导入时可生成修复文本。 |
| 冲突 | 同 path 同 port 视为幂等；同 path 不同 port 必须报冲突；不同 path 可追加。 |
| Certbot renewal | `authenticator = standalone` 必须被识别并迁移为 webroot；webroot renewal 必须被接受。 |
| 自动化测试 | 不调用真实系统命令，不访问公网，不依赖真实 `/etc`。 |

### 可以改进但需记录

| 边界 | 可改进方向 | 约束 |
| --- | --- | --- |
| 模板注释 | 可比 Bash 注释更统一 | route、upstream、include/import 关键字段不能丢。 |
| whitespace | 空行和缩进可稳定化 | 契约测试不做字节级快照。 |
| 操作执行 | 后续可把命令计划接入 Runner 执行 | 执行前必须有 fake runner 测试和显式错误处理。 |

### 明确禁止

- 禁止 Phase 3 自动化测试调用真实 Nginx、Caddy、Certbot、systemd、Let's Encrypt。
- 禁止 Go 模板层直接写系统文件。
- 禁止因为模板实现方便而改变 Phase 0 fixture 的 `.conf + .add` 语义。
- 禁止在已有主 `.conf` 的场景重新生成并覆盖主配置。

## CLI 接口

Phase 3 扩展只读预览命令：

```bash
go run ./cmd/xray gen --format nginx vless-ws-tls
go run ./cmd/xray gen --format nginx-add vless-grpc-tls
go run ./cmd/xray gen --format caddy vless-xhttp-tls
go run ./cmd/xray gen --format caddy-add trojan-xhttp-tls
```

| format | 输出 |
| --- | --- |
| `nginx` | 完整 Nginx site `.conf`。 |
| `nginx-add` | 可追加到 `.conf.add` 的 Nginx location 片段。 |
| `caddy` | 完整 Caddy site `.conf`。 |
| `caddy-add` | 可追加到 `.conf.add` 的 Caddy reverse_proxy 片段。 |

REALITY、VMess TCP、Shadowsocks、Socks 这类非 TLS 前端协议对上述 format 返回协议不支持退出码。

## 数据模型

Phase 3 新增 `internal/frontend` 包族：

```text
internal/frontend/nginx
  render.go      完整站点和 add location 模板
  inspect.go     location 解析、冲突检测、include 修复
  certbot.go     renewal 解析和 webroot 修复
  plan.go        nginx/certbot validate/reload 命令计划

internal/frontend/caddy
  render.go      完整站点和 add reverse_proxy 模板
  inspect.go     reverse_proxy 解析、冲突检测、import 修复
  plan.go        caddy validate/reload 命令计划
```

输入沿用 `protocol.Profile`，输出为字符串或纯数据结构。

## 验收标准

### 文档验收

- 新增本文档，并在 `go-refactor-plan.md` 的 Phase 3 段落中链接。
- 新增 `docs/04-backend/frontend-template-design.md`，描述模板包边界、路径冲突、Certbot renewal 和操作计划。
- `docs/README.md` 的关键文档入口包含 Phase 3 文档和前端模板设计文档。

### 工程验收

- Nginx 模板能为 WS、gRPC、XHTTP、Trojan XHTTP 生成 location。
- Caddy 模板能为 WS、gRPC、XHTTP、Trojan XHTTP 生成 reverse_proxy。
- 完整 Nginx 站点包含 80 challenge、443 TLS、证书路径和 `.add` include。
- 完整 Caddy 站点包含 `encode gzip`、主 reverse_proxy 和 `.add` import。
- Nginx/Caddy 冲突检测能区分：
  - 同 path 同 port：幂等。
  - 同 path 不同 port：冲突。
  - 新 path：可追加。
- include/import 修复函数能为缺失 `.add` 导入的主配置生成修复文本。
- Certbot renewal webroot/standalone 样例均可解析，standalone 可生成 webroot 修复文本。
- 操作计划包含配置测试、reload、Nginx webroot certbot issue、renew dry-run。

### 契约测试验收

- 新增 `tests/testcase-13-go-frontend-templates.sh`，由 `tests/run.sh` 自动发现。
- `testcase-13` 不访问真实 `/etc`，不访问公网，不执行 systemd/Nginx/Caddy/Certbot。
- `testcase-13` 至少断言：
  - `go test ./...` 通过。
  - `gen --format nginx vless-ws-tls` 输出 include、webroot challenge、WS location 和 upstream。
  - `gen --format nginx-add vless-grpc-tls` 输出 gRPC location 和 `grpc_pass`。
  - `gen --format caddy vless-xhttp-tls` 输出 import 和 reverse_proxy。
  - `gen --format caddy-add trojan-xhttp-tls` 输出 XHTTP reverse_proxy。
  - Go 测试覆盖路径冲突和 renewal 迁移。
- 原有 `testcase-01` 到 `testcase-12` 继续通过。

### 安全验收

- Phase 3 自动化测试不得执行真实系统命令。
- 生产模板函数不得写系统文件。
- 高副作用命令必须先以操作计划形式显式呈现，后续阶段接入 Runner 时再执行。

## 实施步骤

### Step 1: 前端模板设计

1. 新增本文档和 `frontend-template-design.md`。
2. 更新 `go-refactor-plan.md` 和 `docs/README.md`。

完成条件：Phase 3 的验收、边界和实现包职责可直接指导编码。

### Step 2: Nginx 模板与检查

1. 新增 `internal/frontend/nginx`。
2. 实现完整站点模板和 `.add` location 模板。
3. 实现 location 解析、冲突检测和 include 修复。
4. 实现 renewal 解析、webroot 修复和操作计划。

完成条件：Go 单元测试覆盖 fixture、冲突和 Certbot renewal。

### Step 3: Caddy 模板与检查

1. 新增 `internal/frontend/caddy`。
2. 实现完整站点模板和 `.add` reverse_proxy 模板。
3. 实现 reverse_proxy 解析、冲突检测和 import 修复。
4. 实现 validate/reload 操作计划。

完成条件：Go 单元测试覆盖 fixture 和冲突。

### Step 4: CLI 与契约测试

1. 扩展 `gen --format` 支持 `nginx`、`nginx-add`、`caddy`、`caddy-add`。
2. 新增 `tests/testcase-13-go-frontend-templates.sh`。
3. 复用 Go 容器运行方式，并默认优先国内镜像源。

完成条件：`bash tests/run.sh`、`bash tests/shellcheck.sh` 均通过。

## 任务拆分建议

| ID | 任务 | 产物 | 优先级 |
| --- | --- | --- | --- |
| P3-01 | Phase 3 文档与模板设计 | 本文档、`docs/04-backend/frontend-template-design.md` | P0 |
| P3-02 | Nginx 模板 | `internal/frontend/nginx/render.go` | P0 |
| P3-03 | Nginx 检查与 Certbot 模型 | `inspect.go`、`certbot.go`、`plan.go` | P0 |
| P3-04 | Caddy 模板 | `internal/frontend/caddy/render.go` | P0 |
| P3-05 | Caddy 检查与操作计划 | `inspect.go`、`plan.go` | P0 |
| P3-06 | `gen` 前端预览命令 | `internal/app` | P0 |
| P3-07 | Go 单元测试 | `*_test.go` | P0 |
| P3-08 | Bash 契约测试 | `tests/testcase-13-go-frontend-templates.sh` | P0 |
| P3-09 | Phase 3 验收检查 | `go test ./...`、`bash tests/run.sh`、ShellCheck | P0 |

## 完成定义

Phase 3 完成时，应能用一句话描述：

Go 已能基于协议 Profile 无副作用生成 Nginx/Caddy 前端配置，判断同域名追加是否安全，修复 `.add` 导入和 Certbot renewal webroot 模型，并把高副作用的配置测试、reload、dry-run 作为可审计操作计划固定下来。
