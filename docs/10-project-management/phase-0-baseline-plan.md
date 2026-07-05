# Phase 0 基线固化实施文档

## 目标

Phase 0 的目标是在 Go 重构正式写入业务逻辑前，先把当前 Bash 主线的可依赖行为固定下来。

这一阶段不追求功能重写，也不改变安装入口。它要回答三个问题：

- 当前 `xray` 命令到底支持哪些用户可见行为。
- 哪些行为在 Go 迁移期间必须兼容，哪些可以趁机改进。
- 后续 Go 实现如何用 fixture、快照和契约测试证明自己没有破坏现有用户配置。

## 范围

### 必做范围

| 类别 | 内容 | 目的 |
| --- | --- | --- |
| 命令矩阵 | 梳理 `add/change/del/info/url/qr/client/gen/update/reinstall/uninstall/mihomo/refresh-sub/sub-url/fix-*` | 明确迁移对象和兼容优先级。 |
| 协议基线 | 固化 REALITY、WS、gRPC、XHTTP、TCP、Shadowsocks、Socks 的输入、JSON、URL 和展示字段 | 防止协议模型迁移时丢字段。 |
| TLS 前端 | 固化 Caddy/Nginx 的 `.conf + .add` 追加模型、路径冲突检测、include 修复 | 防止同域名多协议覆盖配置。 |
| Certbot | 固化 Nginx 模式下证书签发、续期、renewal 配置检查的预期行为 | 为后续 webroot 优先模型提供测试目标。 |
| Mihomo | 固化 YAML 生成、token 文件权限、订阅路由片段 | 防止订阅输出回归。 |
| 发布与回归 | 保留并扩展 `tests/run.sh`、ShellCheck、release asset 契约 | 确保 Bash 主线仍可发布。 |

### 暂不做范围

- 不创建 Go module。
- 不修改 `/usr/local/bin/xray` 的指向。
- 不改变 `/etc/xray`、`/etc/nginx/xray`、`/etc/caddy` 的运行时布局。
- 不新增 Web 管理面板或长期运行的订阅服务。
- 不在 Phase 0 内完成所有 Bash 模块拆分。
- 不把真实 VPS 手动验收替代为完全自动化测试；Phase 0 只定义手动验收记录格式。

## 兼容性边界

### 必须保持兼容

| 边界 | 要求 |
| --- | --- |
| 用户入口 | `install.sh` 仍是一键安装入口，`xray` 仍是用户命令入口。 |
| 命令别名 | 已存在的短命令和别名继续可用，例如 `a/add`、`i/info`、`d/del`、`u/update`、`mihomo/clash`。 |
| 配置来源 | 受管理节点仍以 `/etc/xray/conf/*.json` 为状态来源。 |
| 主配置 | Xray 仍使用 `/etc/xray/config.json` 加 `/etc/xray/conf` 目录运行。 |
| TLS 文件模型 | Nginx/Caddy 继续使用主站点配置加 `.add` 追加片段。 |
| 协议关键字段 | UUID、端口、host、path、SNI、publicKey、flow、network、TLS 字段不能丢失或改变语义。 |
| 订阅安全 | `/etc/xray/sub/token` 继续作为订阅访问控制来源，权限目标为 `600`。 |
| 发布资产 | v1.x 仍发布 `install.sh` 和 `code.zip`，且 `code.zip` 包含 `install.sh`、`xray.sh`、`src/`。 |

### 可以改进但需记录

| 边界 | 可改进方向 | 约束 |
| --- | --- | --- |
| 输出文本 | 错误信息、提示文案、颜色可以更清晰 | 脚本依赖的稳定字段和 URL 行不能无记录变更。 |
| 错误码 | 可以继续迁移到 `error_out` | 老命令不能因错误码变化中断正常流程。 |
| 随机值 | 可以固定 fixture 中的 UUID、端口、path、password | 真实运行仍保持随机生成能力。 |
| Nginx 模板 | 可以调整注释和安全默认值 | location 路由、证书路径、include 模型必须兼容。 |
| Certbot 模型 | 可以从 standalone 迁到 webroot 优先 | 迁移前后 renewal 文件必须可被检查和修复。 |

### 明确不兼容变更

以下变更不能在 Phase 0 合入：

- 删除已发布命令或短别名。
- 改变受管理 JSON 文件命名规则且没有迁移方案。
- 把订阅从静态文件改为运行时 API。
- 让 Nginx 同域名新增协议覆盖已有 `domain.conf`。
- 让只读命令写入系统文件、重启服务或申请证书。
- 让测试依赖真实域名、真实 Let's Encrypt 额度或公网网络。

## 验收标准

### 文档验收

- 命令矩阵文档完成，至少包含命令、别名、读写类型、主要文件副作用、服务副作用、迁移优先级。
- 协议契约文档完成，至少覆盖 REALITY、VLESS-WS-TLS、VLESS-gRPC-TLS、VLESS-XHTTP-TLS、Trojan-XHTTP-TLS、VMess-TCP、Shadowsocks、Socks。
- 兼容性边界已写入本文档或后续测试策略文档。
- Certbot/Nginx 续期风险有明确 Bash 主线修复项和回归用例描述。

### Fixture 验收

建议目录：

```text
tests/fixtures/
|-- xray-conf/
|   |-- vless-reality.json
|   |-- vless-ws-tls.json
|   |-- vless-grpc-tls.json
|   |-- vless-xhttp-tls.json
|   |-- trojan-xhttp-tls.json
|   |-- vmess-tcp.json
|   |-- shadowsocks.json
|   `-- socks.json
|-- nginx/
|   |-- single-domain.conf
|   |-- single-domain.conf.add
|   |-- multi-protocol-domain.conf
|   `-- multi-protocol-domain.conf.add
|-- caddy/
|   |-- single-domain.conf
|   `-- single-domain.conf.add
|-- certbot/
|   |-- renewal-webroot.conf
|   `-- renewal-standalone.conf
`-- mihomo/
    `-- mihomo.yaml
```

验收要求：

- 所有 JSON fixture 可被 `jq .` 校验。
- 所有 Xray JSON fixture 的关键字段有断言，而不是只比较整文件。
- Nginx/Caddy fixture 同时覆盖首次创建和同域名追加。
- Certbot fixture 覆盖 webroot 与 standalone renewal 的识别。
- Mihomo fixture 覆盖支持节点和明确跳过的节点注释。

### 自动化测试验收

- `bash tests/run.sh` 通过。
- `bash tests/shellcheck.sh` 通过，或有已记录且可解释的例外。
- CI 中现有 Bash 语法、ShellCheck、JSON validation、协议完整性、发布契约继续通过。
- 新增测试至少覆盖：
  - 命令矩阵契约。
  - 协议列表和快捷别名契约。
  - `info/url` 从 fixture 读取后的关键输出字段。
  - Nginx `.conf + .add` include 和 location 不覆盖契约。
  - Certbot renewal 模式识别契约。
  - Mihomo YAML 关键字段契约。

### 手动验收

真实 VPS 手动验收只作为 Phase 0 的补充，不作为本地测试替代。

手动验收记录应包含：

- 系统版本、架构、Xray-core 版本、脚本版本。
- TLS 模式：Caddy 或 Nginx。
- 执行命令和输出摘要。
- 生成文件路径和关键字段。
- `xray test`、`nginx -t` 或 `caddy validate` 结果。
- 客户端连通性结果。
- 失败日志路径和处理结论。

## 命令矩阵模板

命令矩阵维护在 `docs/04-backend/command-matrix.md`。

| 命令 | 别名 | 类型 | 主要输入 | 主要输出 | 文件副作用 | 服务副作用 | 迁移优先级 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `info` | `i` | 只读 | 配置名或匹配串 | 配置详情、URL | 无 | 可能触发 IP 探测 | P0 |
| `url` | `qr` | 只读 | 配置名或匹配串 | 分享链接或二维码 | 无 | 无 | P0 |
| `gen` | 无 | 生成预览 | 协议与参数 | Xray JSON | 无 | 无 | P0 |
| `add` | `a` | 写入 | 协议与参数 | JSON、前端配置、订阅刷新 | 写 `/etc/xray/conf` 等 | API 热加载或重启 | P1 |
| `mihomo` | `clash` | 读/生成 | 可选配置名 | YAML | 可选写订阅文件 | 无 | P1 |
| `refresh-sub` | `sub-refresh` | 写入 | 可选域名 | 订阅 URL | 写 YAML/token/前端路由 | reload 前端 | P1 |
| `fix-nginxfile` | 无 | 修复 | 无 | Nginx 主配置 | 写 Nginx 配置 | reload Nginx | P2 |
| `update` | `u/up/U/update.sh` | 下载/写入 | 目标和版本 | 更新结果 | 写核心或脚本 | 可能重启 | P3 |

## 实施步骤

### Step 1: 建立文档基线

1. 新增本文档并在 `go-refactor-plan.md` 的 Phase 0 链接。
2. 新增 `docs/04-backend/command-matrix.md`，按命令矩阵模板补齐所有命令。
3. 新增 `docs/09-testing/test-strategy.md`，描述 fixture、快照、容器测试和手动验收分层。
4. 在 `docs/README.md` 的 Current Key Documents 中加入 Phase 0 文档。

完成条件：文档能让新维护者不读完整 `core.sh` 也能知道 Phase 0 要固定什么。

### Step 2: 建立 fixture 目录

1. 创建 `tests/fixtures` 目录结构。
2. 从当前 Bash 生成结果或手工最小样例中提取稳定 fixture。
3. 对随机字段使用固定值：
   - UUID: `11111111-1111-4111-8111-111111111111`
   - 域名: `example.com`
   - 路径: `/xray-test`
   - 端口: `10001` 起按协议递增
   - REALITY serverName: `www.microsoft.com`
4. 保留一份 fixture 说明文件，记录每个样例来自哪个命令。

完成条件：fixture 不依赖真实 `/etc`、公网网络、systemd 或真实证书。

### Step 3: 补 Bash 契约测试

优先补文本和结构测试，避免一上来就模拟完整 VPS：

1. 协议和别名契约：检查 `protocol_list`、`add()` 快捷分支和 `main()` 命令路由。
2. JSON fixture 契约：用 `jq` 校验关键字段。
3. 前端配置契约：用 `awk`/`grep` 检查 Nginx/Caddy include、location/reverse_proxy、路径冲突样例。
4. Certbot 契约：检查 renewal fixture 中 authenticator/webroot_path/standalone 的识别逻辑。
5. Mihomo 契约：检查 YAML 中 type、network、tls、reality-opts、xhttp-opts、proxy-groups。

完成条件：`tests/run.sh` 能统一执行新增测试，并且失败信息能指向具体契约。

### Step 4: 修 Bash 主线高风险项

优先处理 Go 重构前会污染基线的 Bash 问题：

1. Nginx + Certbot 续期模型：
   - 默认签发和续期都优先使用 webroot。
   - 检查 `/etc/letsencrypt/renewal/*.conf`，发现 standalone renewal 时给出修复或自动迁移方案。
   - `certbot renew --dry-run` 不应要求停止 Nginx。
2. 同域名多协议：
   - 新增 location 只能追加到 `.add`。
   - 缺失 `.add` include 时可修复。
   - 路径重复但端口不同必须失败。
3. REALITY/XHTTP：
   - 保持已验证字段：REALITY 的 `publicKey/serverName/flow/fingerprint`，XHTTP 的 `mode/path/host`。

完成条件：新增契约测试先失败再修复，修复后通过。

### Step 5: 定义 Go 迁移门禁

Phase 1 开始前必须满足：

- Phase 0 文档和 fixture 已合入。
- `tests/run.sh`、ShellCheck、CI 契约通过。
- `info/url/gen/mihomo` 的关键输出已有 fixture 或快照。
- 已明确哪些输出是稳定 API，哪些只是人类提示。
- 对尚未自动化的真实 VPS 场景有手动验收记录模板。

## 任务拆分建议

| ID | 任务 | 产物 | 优先级 |
| --- | --- | --- | --- |
| P0-01 | 命令矩阵梳理 | `docs/04-backend/command-matrix.md` | P0 |
| P0-02 | 测试策略文档 | `docs/09-testing/test-strategy.md` | P0 |
| P0-03 | Fixture 目录和说明 | `tests/fixtures/README.md` | P0 |
| P0-04 | 协议 JSON fixture | `tests/fixtures/xray-conf/*.json` | P0 |
| P0-05 | Nginx/Caddy fixture | `tests/fixtures/nginx/*`, `tests/fixtures/caddy/*` | P0 |
| P0-06 | Certbot renewal fixture | `tests/fixtures/certbot/*.conf` | P0 |
| P0-07 | Mihomo fixture | `tests/fixtures/mihomo/mihomo.yaml` | P1 |
| P0-08 | 契约测试接入 `tests/run.sh` | `tests/testcase-06-*.sh` 起 | P0 |
| P0-09 | Nginx + Certbot Bash 修复 | `src/nginx.sh` 和回归测试 | P0 |
| P0-10 | Phase 1 Go 门禁检查 | 评审记录或 checklist | P0 |

当前状态：

| ID | 状态 | 说明 |
| --- | --- | --- |
| P0-01 | 已完成 | 命令矩阵已维护在 `docs/04-backend/command-matrix.md`。 |
| P0-02 | 已完成 | 测试策略已维护在 `docs/09-testing/test-strategy.md`。 |
| P0-03 | 已完成 | `tests/fixtures/README.md` 已说明目录、固定值和约束。 |
| P0-04 | 已完成 | `tests/fixtures/xray-conf/*.json` 已覆盖 Phase 0 协议，并由 `testcase-07` 断言。 |
| P0-05 | 已完成 | Nginx/Caddy fixture 已覆盖 `.conf + .add`、追加路由和冲突样例，并由 `testcase-08` 断言。 |
| P0-06 | 已完成 | Certbot webroot/standalone renewal fixture 已建立，并由 `testcase-09` 断言。 |
| P0-07 | 已完成 | Mihomo fixture 已覆盖支持节点和 unsupported skip，并由 `testcase-10` 断言。 |
| P0-08 | 已完成 | `tests/testcase-06-*` 到 `tests/testcase-10-*` 已接入 `tests/run.sh` 自动发现流程。 |
| P0-09 | 已完成 | `src/nginx.sh` 已改为 webroot-first，并加入 renewal 检查/迁移回归测试。 |
| P0-10 | 已完成 | `bash tests/run.sh` 与 `bash tests/shellcheck.sh` 已通过，可作为 Phase 1 启动门禁。 |

## 完成定义

Phase 0 完成时，应能用一句话描述基线：

当前 Bash 版本的命令矩阵、文件副作用、协议输出、TLS 前端配置、Certbot renewal 行为和 Mihomo 订阅格式都有明确文档与可重复测试；Go Phase 1 只能在这些边界内读取和复现行为，不能凭实现便利改变用户可见契约。
