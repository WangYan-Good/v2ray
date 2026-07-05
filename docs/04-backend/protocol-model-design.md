# 协议模型设计

## 目标

本文档定义 Phase 2 的 Go 协议模型和生成边界。它承接 Phase 1 的 `config.Node` 读取模型，但不把读取模型直接当作写入模型使用。

核心原则：

- `config.Node` 表达“已经存在的运行时配置”。
- `protocol.Profile` 表达“准备生成的协议配置档”。
- `protocol.Profile` 可以转换为 `config.Node`，以复用 URL、info 和 Mihomo 字段语义。
- 生成函数只返回字符串或 `[]byte`，不写文件、不执行系统命令。

## 包边界

```text
internal/protocol/
  profile.go       Profile、preset、字段校验、Node 转换
  xray_json.go     server inbound JSON 生成
  client_json.go   client outbound JSON 生成
  mihomo.go        Mihomo 节点和订阅 YAML 生成
  url.go           Phase 1 分享 URL 生成
```

Phase 2 暂不新增独立 `internal/config/writer`，避免误导为已经支持真实写入。

## Profile 字段

| 字段 | 说明 |
| --- | --- |
| `Key` | 稳定 profile 名称，用于 CLI 查询和测试，例如 `vless-reality`。 |
| `Name` | 节点展示名和生成产物标识，例如 `VLESS-XTLS-uTLS-REALITY-10001`。 |
| `Protocol` | `vless`、`trojan`、`vmess`、`shadowsocks`、`socks`。 |
| `Port` | inbound 监听端口。 |
| `Listen` | inbound listen 地址。 |
| `ID` | VLESS/VMess UUID，Socks username。 |
| `Password` | Trojan/SS/Socks 密码。 |
| `Method` | Shadowsocks 加密方法。 |
| `Network` | `tcp`、`ws`、`grpc`、`xhttp`。 |
| `Security` | `reality`、`tls` 或空。 |
| `Host` | TLS 前端域名。 |
| `Path` | WS/XHTTP path。 |
| `ServiceName` | gRPC serviceName。 |
| `Flow` | REALITY flow。 |
| `ServerName` | REALITY SNI。 |
| `Fingerprint` | REALITY client fingerprint，默认 `ios`。 |
| `PublicKey` | REALITY public key。 |
| `PrivateKey` | REALITY private key。 |
| `HeaderType` | VMess TCP header type，Phase 2 支持 `none`。 |
| `XHTTPMode` | XHTTP mode，默认 `auto`。 |

## Preset

Phase 2 固定 8 个 preset，与 Phase 0 fixture 一一对应：

- `vless-reality`
- `vless-ws-tls`
- `vless-grpc-tls`
- `vless-xhttp-tls`
- `trojan-xhttp-tls`
- `vmess-tcp`
- `shadowsocks`
- `socks`

固定值来自 `docs/07-data/protocol-contracts.md`：

- host: `example.com`
- UUID: `11111111-1111-4111-8111-111111111111`
- path: `/xray-test`
- serviceName: `xray-grpc`
- REALITY SNI: `www.microsoft.com`
- REALITY public/private key: `example-public-key` / `example-private-key`
- 端口：`10001` 起递增

## Xray JSON 生成

生成函数输出单节点 server inbound JSON：

```json
{
  "inbounds": [
    {
      "tag": "vless-xhttp-tls",
      "port": 10004,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {},
      "streamSettings": {}
    }
  ]
}
```

关键要求：

- VLESS/VMess/Trojan 使用 `settings.clients[0]`。
- Shadowsocks 使用 `settings.method/password/network`。
- Socks 使用 `settings.accounts[0].user/pass`、`auth=password`、`udp=true`。
- REALITY 使用 `streamSettings.realitySettings.serverNames/privateKey/publicKey`。
- WS 使用 `wsSettings.path` 和 `headers.Host`。
- gRPC 使用 `grpcSettings.serviceName`。
- XHTTP 使用 `xhttpSettings.host/path/mode`。
- VMess TCP 使用 `tcpSettings.header.type=none`。

## Client JSON 生成

Client JSON 是最小 outbound 预览，不是完整客户端配置文件。它用于固定协议关键字段，为后续导出功能提供稳定基础。

输出结构：

```json
{
  "outbounds": [
    {
      "tag": "vless-xhttp-tls",
      "protocol": "vless",
      "settings": {},
      "streamSettings": {}
    }
  ]
}
```

要求：

- server 使用公开连接地址：TLS 前端协议使用 host，REALITY/直连协议使用 `203.0.113.10`。
- port 使用公开连接端口：TLS 前端协议为 `443`，直连协议为 inbound port。
- 保留 UUID/password/method/network/security/path/serviceName/REALITY 字段。
- Phase 2 不生成 routing、DNS、log、inbounds 等完整客户端配置。

## Mihomo 生成

Mihomo 生成包含两个层级：

- 单节点 proxy YAML。
- 默认订阅预览 YAML。

支持范围：

| 协议 | Mihomo 行为 |
| --- | --- |
| VLESS REALITY | 输出 `type: vless`、`tls: true`、`reality-opts`。 |
| VLESS WS | 输出 `network: ws`、`ws-opts`。 |
| VLESS gRPC | 输出 `network: grpc`、`grpc-opts`。 |
| VLESS XHTTP | 输出 `network: xhttp`、`alpn: h2`、`xhttp-opts`。 |
| VMess TCP | 仅 `header.type=none` 输出 `type: vmess`。 |
| Shadowsocks | 输出 `type: ss`。 |
| Socks | 输出 `type: socks5`。 |
| Trojan XHTTP | 输出 unsupported skip reason。 |

## 测试边界

Go 单元测试：

- Profile preset 覆盖所有 fixture 名称。
- Xray JSON 可解析并与 fixture 关键字段等价。
- Client JSON 包含公开连接地址、端口和认证字段。
- Mihomo 生成支持节点和 unsupported skip。

Bash 契约测试：

- `tests/testcase-12-go-protocol-generation.sh`
- 通过 Go 容器或本地 Go 运行 `go test ./...`。
- 通过 `go run ./cmd/xray gen ...` 验证 CLI 预览输出。
- 默认优先使用国内 Go 镜像源。

## 后续扩展

- Phase 3 可把 Profile 作为 Nginx/Caddy 模板输入。
- Phase 4 可把下载、安装和写入流程接到 Profile 生成结果。
- Phase 5 才允许 Go CLI 接管真实 `add/change/del` 命令。
