# Go 模块设计

## 目标

本文档定义 Phase 1 的 Go 工程骨架。设计原则是小而稳：只读、可测试、可委托、可逐步扩展。

## 目录结构

```text
go.mod
cmd/xray/
  main.go
internal/app/
  app.go
internal/config/
  reader.go
  node.go
internal/protocol/
  url.go
internal/ui/
  output.go
```

Phase 1 不需要引入第三方依赖。优先使用 Go 标准库：

- `encoding/json`
- `encoding/base64`
- `flag`
- `fmt`
- `io`
- `net/url`
- `os`
- `path/filepath`
- `sort`
- `strings`

## 包职责

| 包 | 职责 | 禁止事项 |
| --- | --- | --- |
| `cmd/xray` | 程序入口，传入 `os.Args`、stdout、stderr | 不放业务逻辑。 |
| `internal/app` | CLI flag、命令路由、错误码 | 不直接解析复杂 JSON。 |
| `internal/config` | 扫描配置目录、读取 inbound JSON、匹配节点 | 不生成配置、不写文件。 |
| `internal/protocol` | 从节点字段生成分享 URL | 不访问文件系统。 |
| `internal/ui` | 格式化 `info/status/version` 输出 | 不决定业务语义。 |

## 只读边界

Phase 1 production 代码不得调用：

- `os.WriteFile`
- `os.Mkdir` / `os.MkdirAll`
- `os.Remove` / `os.RemoveAll`
- `os.Rename`
- `exec.Command`
- 网络请求 API，例如 `http.Get`

测试代码可以使用临时目录，但不能访问真实 `/etc` 或公网。

## CLI 设计

入口：

```bash
go run ./cmd/xray [--conf-dir DIR] [--config FILE] <command> [name]
```

全局 flag：

- `--conf-dir`: 默认 `/etc/xray/conf`
- `--config`: 默认 `/etc/xray/config.json`
- `--no-color`: 默认 `true`

命令：

- `version`, `ver`, `v`
- `status`, `s`
- `info`, `i`
- `url`

错误码：

| 情况 | 退出码 |
| --- | --- |
| 成功 | `0` |
| 命令或参数错误 | `2` |
| 配置读取或匹配失败 | `3` |
| 协议暂不支持 | `4` |
| 未预期错误 | `1` |

## 节点模型

Phase 1 使用扁平节点模型，避免过早完整建模 Xray schema。

```text
Node
  Name
  FileName
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
```

字段来源：

- VLESS/VMess ID: `.settings.clients[0].id`
- Trojan password: `.settings.clients[0].password`
- Shadowsocks method/password: `.settings.method` / `.settings.password`
- Socks user/pass: `.settings.accounts[0].user/pass`
- Network/security: `.streamSettings.network/security`
- WS path/host: `.streamSettings.wsSettings.path` / `.headers.Host`
- gRPC service: `.streamSettings.grpcSettings.serviceName`
- XHTTP path/host/mode: `.streamSettings.xhttpSettings.*`
- REALITY serverName/publicKey: `.streamSettings.realitySettings.serverNames[0]` / `.publicKey`

## 测试策略

Go 单元测试：

- `internal/config`: fixture 扫描、匹配、多匹配错误、JSON 字段读取。
- `internal/protocol`: URL scheme 和关键 query 参数。
- `internal/app`: 命令别名、错误码、stdout/stderr 分离。

Bash 契约测试：

- `tests/testcase-11-go-cli-readonly.sh`
- 使用 `go run ./cmd/xray --conf-dir tests/fixtures/xray-conf ...`
- 不读取真实 `/etc`。

验收命令：

```bash
go test ./...
bash tests/run.sh
bash tests/shellcheck.sh
```

## 后续扩展边界

- Phase 2 可在 `internal/protocol` 中扩展强类型协议模型和 JSON 生成。
- Phase 3 可新增 `internal/frontend/nginx` 与 `internal/frontend/caddy`，但不得塞入 Phase 1 包。
- Phase 5 才允许引入 `internal/legacy` 委托 Bash 或切换 `/usr/local/bin/xray`。
