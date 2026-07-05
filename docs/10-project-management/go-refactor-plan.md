# Go 重构计划

## 目标

将当前 Bash 为主的 Xray 安装与管理脚本，逐步重构为 `Go CLI + Bash bootstrap` 架构。

目标不是一次性推倒重写，而是在保持现有安装方式和用户命令兼容的前提下，把高风险逻辑从全局变量驱动的 Shell 迁移到可测试、可发布、可回滚的 Go 二进制中。

## 为什么选择 Go

- 单文件二进制，适合服务器一键安装和离线分发。
- 跨架构发布简单，适配 x86_64 和 ARM64。
- 标准库覆盖 HTTP 下载、SHA256、JSON、模板、进程执行、文件系统和信号处理。
- 错误处理、结构化数据和单元测试能力明显优于 Bash。
- 运维用户不需要额外安装 Python、Node.js 或复杂运行时。

## 非目标

- 不引入 Web 管理面板。
- 不改变 Xray Core 的配置语义。
- 不在第一阶段替换所有 Bash 脚本。
- 不把 Nginx、Caddy、Certbot 重新实现为内置服务。
- 不改变 `/etc/xray`、`/etc/nginx/xray`、`/etc/caddy` 的现有运行时布局，除非有明确迁移方案。

## 目标架构

```text
install.sh
  |
  | downloads/verifies
  v
/usr/local/bin/xray  -> Go binary
  |
  +-- install/update/uninstall
  +-- add/change/del/info
  +-- nginx/caddy/certbot integration
  +-- mihomo subscription generation
  +-- diagnostics and repair
```

`install.sh` 保留为最小 bootstrap：

- 检测系统和架构。
- 下载对应架构的 Go 二进制。
- 写入 `/usr/local/bin/xray`。
- 必要时调用 `xray install` 完成系统级安装。

## 模块划分

```text
cmd/xray/                 CLI 入口
internal/app/             命令编排
internal/system/          OS、权限、架构、包管理器、systemd
internal/xraycore/        Xray Core 下载、版本、服务控制、API 热加载
internal/config/          Xray JSON 读写、主配置、节点配置
internal/protocol/        协议模型、参数校验、URL 生成
internal/frontend/nginx/  Nginx 模板、reload/test、Certbot 集成
internal/frontend/caddy/  Caddy 模板和 reload
internal/cert/            Certbot 签发、续期、renewal 检查
internal/subscription/    Mihomo YAML 和订阅 token
internal/download/        下载、校验和、重试、代理
internal/ui/              交互式 prompt 和终端输出
internal/legacy/          Bash 兼容与迁移辅助
```

## 分阶段计划

### Phase 0: 基线固化

- 梳理现有命令矩阵：`add/change/del/info/update/reinstall/uninstall/mihomo/refresh-sub/sub-url/fix-*`。
- 为当前 Bash 行为补关键契约测试，尤其是 Nginx + Certbot 续期、同域名多协议、REALITY、XHTTP。
- 建立 fixture：示例 Xray JSON、Nginx 配置、Caddy 配置、Certbot renewal 配置。
- 定义兼容性边界：哪些输出必须保持，哪些可以改进。

操作实施文档：`docs/10-project-management/phase-0-baseline-plan.md`

验收：

- 当前 `tests/run.sh` 通过。
- 命令矩阵、兼容性边界、fixture 目录和测试策略文档完成。
- 新增的 Go 迁移契约测试能描述现有 Bash 行为，至少覆盖 `info/url/gen`、REALITY、XHTTP、同域名多协议、Nginx + Certbot renewal、Mihomo YAML。
- Phase 1 开始前，只读命令的稳定输出字段和允许变化的人类提示文本已经明确区分。

### Phase 1: Go 骨架与只读命令

- 创建 Go module 和 `cmd/xray`。
- 实现 `version`、`status`、`info`、`url` 的只读路径。
- 从 `/etc/xray/conf/*.json` 读取现有节点配置。
- 输出保持和当前脚本大体兼容。

操作实施文档：`docs/10-project-management/phase-1-go-cli-plan.md`

验收：

- Go CLI 能读取真实或 fixture 配置并生成节点信息。
- 不写系统文件，不影响现有 Bash 安装。
- `go test ./...` 通过。
- `go run ./cmd/xray --conf-dir tests/fixtures/xray-conf info vless-reality` 能输出 REALITY 稳定字段。
- `go run ./cmd/xray --conf-dir tests/fixtures/xray-conf url vless-xhttp` 能输出包含 `security=tls`、`type=xhttp`、`path` 的 VLESS URL。
- 新增只读 Go CLI 契约测试接入 `tests/run.sh`。

### Phase 2: 协议模型与配置生成

- 用 Go struct 表达协议配置档。
- 实现 VMess、VLESS、Trojan、Shadowsocks、Socks 的 JSON 生成。
- 优先覆盖当前已启用协议：REALITY、WS、gRPC、XHTTP、TCP、SS、Socks。
- 生成 URL、客户端 JSON、Mihomo 节点。

操作实施文档：`docs/10-project-management/phase-2-protocol-generation-plan.md`

验收：

- Go Profile 能覆盖 Phase 0 的 8 个协议 fixture。
- Go 生成的 JSON 通过 `xray test` 或 fixture 校验。
- 与 Bash 生成结果在关键字段上等价。
- `gen` 预览命令只输出 stdout，不写系统文件。
- Mihomo 生成包含支持节点和 Trojan XHTTP unsupported skip 注释。

### Phase 3: Nginx/Caddy 模板化

- 将 Nginx/Caddy 配置生成改为 Go 模板。
- 保留 `.conf + .add` 的多协议共存模型。
- 实现路径冲突检测、include 修复、配置测试和 reload。
- 修复 Certbot 自动续期模型：Nginx 模式默认使用 webroot，并确保 renewal 配置不依赖 standalone。

操作实施文档：`docs/10-project-management/phase-3-frontend-template-plan.md`

验收：

- 同域名多协议追加不覆盖已有配置。
- Go 模板能生成 Nginx/Caddy 完整站点和 `.add` 追加片段。
- 路径冲突检测能区分可追加、幂等和冲突。
- Certbot renewal standalone 会被识别并生成 webroot 修复文本。
- `certbot renew --dry-run` 作为 Nginx 操作计划的一部分固定；真实 VPS 验收时在 Nginx 运行状态下执行。

### Phase 4: 安装、更新、下载

- 迁移 Xray Core 下载、脚本/二进制更新、SHA256 校验。
- 支持 GitHub Release 资产选择和代理环境变量。
- 统一错误码、日志和清理逻辑。
- `install.sh` 缩减为下载 Go 二进制并调用 `xray install`。

操作实施文档：`docs/10-project-management/phase-4-install-download-plan.md`

验收：

- Go 下载计划能覆盖 Xray Core、脚本、Caddy、dat、jq 和 Go CLI 二进制资产。
- SHA256、Xray `.dgst`、Caddy checksums 和 GitHub asset digest 解析均有单元测试。
- proxy 环境变量和 unsupported arch 错误可被契约测试断言。
- Release workflow 构建并上传 linux amd64/arm64 Go CLI tarball，同时保留 `code.zip` 和 `install.sh`。
- 新安装、重新安装、保留配置更新的操作步骤以 plan 形式固定；真实默认入口切换进入 Phase 5。

### Phase 5: 命令切换与兼容层

- `/usr/local/bin/xray` 默认指向 Go 二进制。
- 对尚未迁移的命令临时委托旧 Bash。
- 记录迁移警告和兼容路径。
- 发布预览版本，允许用户回退到 Bash 版本。

验收：

- 主路径命令由 Go 执行。
- 未迁移命令仍可用或明确提示。

### Phase 6: 清理 Bash 旧实现

- 删除已完全迁移的 Bash 逻辑。
- 保留最小 bootstrap 和必要的故障恢复脚本。
- 文档更新到 Go CLI 为主。

验收：

- Bash 不再承载核心业务逻辑。
- 发布包结构稳定。

## 优先迁移顺序

1. 配置读取与 `info/url`。
2. 协议模型和 JSON 生成。
3. Mihomo 订阅生成。
4. Nginx/Caddy 配置模板。
5. Certbot 签发与续期。
6. 下载、安装、更新。
7. 删除、修改、修复命令。

这个顺序能先拿到高测试收益，再处理最危险的系统副作用。

## 风险与对策

| 风险 | 对策 |
| --- | --- |
| 行为兼容破坏现有用户配置 | 使用 fixture 和快照测试覆盖现有 JSON、Nginx、Caddy 输出。 |
| 系统命令副作用难测试 | 抽象 `Runner` 和 filesystem 接口，单元测试用 fake，集成测试用容器。 |
| Certbot 续期继续失败 | 改为 webroot 优先，并显式检查 `/etc/letsencrypt/renewal/*.conf`。 |
| 发布包复杂度上升 | 使用 GitHub Actions 为 amd64/arm64 构建 release assets。 |
| 一次性迁移过大 | 保留 Bash 兼容委托，按命令逐步切换。 |

## 测试策略

- 单元测试：协议参数、JSON 生成、URL 生成、模板渲染。
- 快照测试：Nginx/Caddy 配置、Mihomo YAML。
- 集成测试：容器内模拟 Debian/Ubuntu/CentOS 包管理器和 systemd 边界。
- 手动验收：真实 VPS 上测试 Nginx + Certbot、Caddy、REALITY、XHTTP。
- 回归测试：保留当前 `tests/run.sh`，逐步加入 Go test 和 fixture 检查。

## 发布策略

- `v1.x`：Bash 主线，逐步补测试和修复证书续期。
- `v2.0.0-alpha`：Go CLI 只读命令和配置生成预览。
- `v2.0.0-beta`：Go CLI 管理主路径，Bash 兼容未迁移命令。
- `v2.0.0`：Go CLI 成为默认入口。

## 第一批建议任务

- [x] 新增 `docs/09-testing/test-strategy.md`，定义 fixture 和容器测试策略。
- [x] 新增 `docs/04-backend/command-matrix.md`，梳理 Phase 0 命令矩阵与兼容优先级。
- [x] 新增 `docs/04-backend/go-module-design.md`，细化 Go 包结构。
- [x] 修复 Nginx + Certbot 自动续期问题，作为 Go 重构前的 Bash 主线稳定项。
- [x] 为当前协议生成逻辑建立快照样例。
