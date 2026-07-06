# 测试策略

## 目标

测试体系服务于两个目标：

- 保护 Go CLI runtime 继续可发布。
- 为协议、前端、订阅、安装和真实 VPS 验收提供可重复的行为基线。

测试重点不是覆盖每一行实现，而是覆盖用户可见契约和高风险副作用边界。

## 分层

| 层级 | 工具 | 运行位置 | 覆盖内容 |
| --- | --- | --- | --- |
| 静态检查 | `bash -n`, ShellCheck | CI、本地 | Shell 语法、常见风险。 |
| 文本契约 | `rg`, `grep`, `awk` | CI、本地 | 命令路由、协议列表、发布资产、关键分支存在性。 |
| Fixture 结构测试 | `jq`, `awk`, `diff` | CI、本地 | Xray JSON、Nginx/Caddy 片段、Mihomo YAML、Certbot renewal。 |
| 快照测试 | Shell helper 或 Go test | CI、本地 | 稳定输出和模板渲染结果。 |
| 容器集成 | Docker | 手动或后续 CI | 包管理器、文件布局、systemd 边界替身。 |
| 真实 VPS 验收 | 手动 | 发布前 | 真实证书、真实服务 reload、客户端连通性。 |

## Fixture 规范

Fixture 必须满足：

- 不读取或写入真实 `/etc`。
- 不依赖公网 DNS、Let's Encrypt、GitHub 或 systemd。
- 随机字段固定，方便断言。
- 每个 fixture 有来源说明：对应命令、协议、关键字段。
- 断言优先检查结构和关键字段，不默认整文件逐字节相等。

建议固定值：

| 字段 | 值 |
| --- | --- |
| 域名 | `example.com` |
| UUID | `11111111-1111-4111-8111-111111111111` |
| REALITY serverName | `www.microsoft.com` |
| REALITY publicKey | `example-public-key` |
| path | `/xray-test` |
| gRPC serviceName | `xray-grpc` |
| 起始端口 | `10001` |
| Shadowsocks password | `example-password` |
| Socks username | `example-user` |

## Phase 0 必测契约

### 命令契约

- Go CLI 中已发布命令和别名仍存在。
- Go `add` 中快捷协议映射仍存在。
- Go profile/model 包含当前必需协议。
- 发布包仍包含 `install.sh`、Go tarball 和 `checksums.txt`，且不再包含 `code.zip`。

### Xray JSON 契约

每个协议 fixture 至少断言：

- `.inbounds[0].protocol`
- `.inbounds[0].port`
- `.inbounds[0].listen`
- `.inbounds[0].settings`
- `.inbounds[0].streamSettings.network`
- TLS/REALITY/XHTTP 特有字段

### URL 契约

URL 测试不应依赖颜色和横线，只检查：

- scheme: `vmess://`、`vless://`、`trojan://`、`ss://`、`socks://`
- server/host 和 port
- type/network
- path 或 serviceName
- security/tls/reality
- REALITY 的 `sni`、`pbk`、`flow`

### Nginx/Caddy 契约

- 首次创建生成主站点文件。
- 同域名新增协议只追加 `.add`。
- 主站点文件包含 `.add` include/import。
- 相同 path + 相同 port 可视为幂等。
- 相同 path + 不同 port 必须判定冲突。
- `refresh-sub` 写入的订阅路由可重复执行且不会重复堆叠。

### Certbot 契约

- 能识别 webroot renewal。
- 能识别 standalone renewal。
- Nginx 模式目标状态是 webroot 优先。
- `certbot renew --dry-run` 的设计不要求停止 Nginx。
- renewal 检查逻辑不能依赖真实证书目录。

### Mihomo 契约

- 支持 VMess WS/gRPC、VLESS WS/gRPC/XHTTP/REALITY、Trojan WS/gRPC、Shadowsocks、Socks。
- 不支持项要输出明确 skip 注释，而不是静默丢失。
- token 文件权限目标为 `600`。
- YAML 文件权限目标为 `644`。
- `proxy-groups` 至少包含支持节点和 `DIRECT`。

## 测试文件命名

现有测试使用 `tests/testcase-*.sh` 并由 `tests/run.sh` 统一执行。新增测试建议从 `06` 开始：

```text
tests/testcase-06-command-matrix.sh
tests/testcase-07-fixture-json.sh
tests/testcase-08-frontend-templates.sh
tests/testcase-09-certbot-renewal.sh
tests/testcase-10-mihomo-contracts.sh
```

每个测试应输出清晰失败原因，避免只显示 `grep` 失败。

## Go 迁移测试门禁

Phase 1 的 Go 只读命令合入前，应满足：

- Bash fixture 和契约测试已存在。
- Go 读取 fixture 后输出的稳定字段与 Bash 基线一致。
- Go 只读命令不写文件、不 reload 服务、不调用 Certbot。
- 所有差异都归类为：
  - 稳定契约差异：必须修复。
  - 人类提示差异：允许，但需记录。
  - Bash bug 差异：先在 Bash 主线修复或在兼容边界中记录。

## 手动验收记录模板

```text
日期:
系统:
架构:
Xray-core 版本:
脚本版本:
TLS 模式:

命令:
结果摘要:
生成文件:
关键字段:
验证命令:
验证结果:
客户端连通性:
失败日志:
结论:
```
