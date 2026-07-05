# 协议契约

## 目的

本文档固定 Phase 0 期间必须保留的协议输入、Xray JSON 字段、URL 字段和 Mihomo 订阅边界。Go 重构时，这些字段视为用户可见兼容契约。

## 固定测试值

| 字段 | 值 |
| --- | --- |
| 域名 | `example.com` |
| UUID | `11111111-1111-4111-8111-111111111111` |
| 通用 path | `/xray-test` |
| gRPC serviceName | `xray-grpc` |
| REALITY serverName | `www.microsoft.com` |
| REALITY publicKey | `example-public-key` |
| REALITY privateKey | `example-private-key` |
| Shadowsocks password | `example-password` |
| Socks username | `example-user` |
| Socks password | `example-password` |

## 协议矩阵

| 协议 | 输入 | Xray JSON 关键字段 | URL 关键字段 | Mihomo |
| --- | --- | --- | --- | --- |
| `VLESS-XTLS-uTLS-REALITY` | `xray add reality [port] [uuid] [servername]` | `protocol=vless`、`network=tcp`、`security=reality`、`flow=xtls-rprx-vision`、`serverNames[0]`、`publicKey/privateKey` | `vless://`、`security=reality`、`type=tcp`、`sni`、`pbk`、`flow=xtls-rprx-vision`、`fp=ios` | 支持，输出 `type: vless`、`tls: true`、`reality-opts`。 |
| `VLESS-WS-TLS` | `xray add vws [host] [uuid] [/path]` | `protocol=vless`、`listen=127.0.0.1`、`network=ws`、`wsSettings.path`、`headers.Host` | `vless://`、`security=tls`、`type=ws`、`host`、`path` | 支持，输出 `network: ws` 和 `ws-opts`。 |
| `VLESS-gRPC-TLS` | `xray add vgrpc [host] [uuid] [service]` | `protocol=vless`、`listen=127.0.0.1`、`network=grpc`、`grpcSettings.serviceName` | `vless://`、`security=tls`、`type=grpc`、`serviceName` | 支持，输出 `network: grpc` 和 `grpc-opts`。 |
| `VLESS-XHTTP-TLS` | `xray add vxhttp [port] [uuid] [host] [path]` | `protocol=vless`、`listen=127.0.0.1`、`network=xhttp`、`xhttpSettings.host`、`path`、`mode=auto` | `vless://`、`security=tls`、`type=xhttp`、`host`、`path` | 支持，输出 `network: xhttp`、`alpn: h2`、`xhttp-opts`。 |
| `Trojan-XHTTP-TLS` | `xray add txhttp [port] [password] [host] [path]` | `protocol=trojan`、`listen=127.0.0.1`、`network=xhttp`、`xhttpSettings.mode=auto` | `trojan://`、`security=tls`、`type=xhttp`、`host`、`path` | 当前不支持，必须输出 skip 原因。 |
| `VMess-TCP` | `xray add tcp [port] [uuid] [type]` | `protocol=vmess`、`listen=0.0.0.0`、`network=tcp`、`clients[0].id`、`header.type` | `vmess://` base64 JSON，包含 `net=tcp`、`type`、`id` | 仅 `header.type=none` 视为支持。 |
| `Shadowsocks` | `xray add ss [port] [password] [method]` | `protocol=shadowsocks`、`method`、`password`、`network=tcp,udp` | `ss://` 包含 method/password/server/port | 支持，输出 `type: ss`。 |
| `Socks` | `xray add socks [port] [username] [password]` | `protocol=socks`、`accounts[0].user/pass`、`udp=true` | `socks://` 包含 username/password/server/port | 支持，输出 `type: socks5`。 |

## 兼容边界

- `listen` 语义必须保持：TLS 前端代理协议监听 `127.0.0.1`，直连协议监听 `0.0.0.0`。
- REALITY 不依赖 Nginx/Caddy 前端，必须保留 `serverName`、`publicKey`、`flow` 和 `fp=ios`。
- XHTTP 默认 `mode` 为 `auto`，H2/HTTP 兼容模式不能覆盖 XHTTP 的 `auto` 语义。
- Trojan XHTTP 的 Xray 配置可以生成，但 Mihomo 订阅必须明确 skip，不能静默丢节点。
- 人类提示文本可以优化；上述 JSON、URL、Mihomo 关键字段不应无记录变更。
