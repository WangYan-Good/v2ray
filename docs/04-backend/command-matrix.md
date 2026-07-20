# 命令矩阵

## 目的

本文档记录当前 Bash 主线的用户命令、别名、读写类型和副作用边界，为 Go 重构提供兼容基线。

迁移优先级含义：

- P0: Phase 1/2 前必须固定契约，优先迁移或优先测试。
- P1: 配置生成和订阅相关，进入写入路径前必须固定。
- P2: 系统修复和 TLS 前端相关，进入前端模板化前必须固定。
- P3: 下载、安装、更新、卸载等高副作用路径，最后迁移。

## 命令总览

| 命令 | 别名 | 类型 | 主要输入 | 主要输出 | 文件副作用 | 服务副作用 | 迁移优先级 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `version` | `v`, `ver` | 只读 | 无 | Xray-core、脚本、Caddy 版本 | 无 | 无 | P0 |
| `status` | `s` | 只读 | 无 | Xray/Caddy/Nginx 状态 | 无 | 无 | P0 |
| `info` | `i` | 只读 | 可选配置名 | 配置详情、URL | 无 | 可能触发公网 IP 探测 | P0 |
| `url` | 无 | 只读 | 配置名 | 分享 URL | 无 | 可能触发公网 IP 探测 | P0 |
| `qr` | 无 | 只读 | 配置名 | 二维码或二维码链接 | 无 | 可能调用 `qrencode` | P1 |
| `gen` | 无 | 生成预览 | 协议和参数 | Xray inbound JSON | 无 | 无 | P0 |
| `download-plan` | 无 | 生成预览 | 组件、版本、架构、代理 | 下载资产与安装步骤计划 | 无 | 无 | P3 |
| `switch-plan` | 无 | 生成预览 | 可选模式 | Go/Bash 入口切换和回滚计划 | 无 | 无 | P3 |
| `install` | 无 | 安装/写入 | `--tls`、`--acme-email` 或显式 `--acme-no-email` | 安装结果和下一步 | 系统依赖、Xray、前端和 hook | 验证后 enable Xray/Nginx | P3 |
| `client` | `genc` | 生成预览 | 配置名 | 客户端 outbound/full JSON | 无 | 无 | P1 |
| `add` | `a` | 写入 | 协议和参数 | 节点信息、URL | 写 `/etc/xray/conf`、可能写前端配置和订阅 | API 热加载、重启 Xray/Caddy/Nginx | P1 |
| `change` | `c`, `config` | 写入 | 配置名、字段和值 | 更新后节点信息 | 重写节点 JSON、可能更新前端配置和订阅 | API 热加载、重启服务 | P2 |
| `del` | `d`, `rm` | 写入 | 配置名 | 删除结果 | 删除节点 JSON、可能删除前端片段、刷新订阅 | API 删除、重启服务 | P2 |
| `ddel` | `dd` | 写入 | 多个配置名 | 批量删除结果 | 同 `del` | 同 `del` | P2 |
| `fix` | 无 | 写入 | 可选配置名 | 修复结果 | 重建单个节点 JSON 或前端相关配置 | 可能重启服务 | P2 |
| `fix-all` | 无 | 写入 | 无 | 批量修复结果 | 重建所有受管理节点、刷新订阅 | 可能重启服务 | P2 |
| `fix-config.json` | 无 | 写入 | 无 | 修复结果 | 重写 `/etc/xray/config.json` | 无 | P2 |
| `fix-caddyfile` | 无 | 写入 | 无 | 修复结果 | 重写或修复 Caddy 导入 | 重启 Caddy | P2 |
| `fix-nginxfile` | 无 | 写入 | 无 | include、renewal、旧路径和 redirect 修复结果 | 原子更新项目管理文件与 deploy hook | `nginx -t` 成功后 reload | P2 |
| `mihomo` | `clash` | 生成预览 | 可选配置名 | Mihomo YAML | 无 | 无 | P1 |
| `refresh-sub` | `sub-refresh` | 写入 | 可选域名 | 订阅 URL | 写 `/etc/xray/sub/mihomo.yaml`、token、前端路由 | reload Caddy/Nginx | P1 |
| `sub-url` | 无 | 只读 | 可选域名 | 订阅 URL | 可能创建 token | 无 | P1 |
| `update` | `u`, `up` | 下载/写入 | `core/sh/caddy/nginx/dat`、版本 | 更新结果 | 覆盖核心、脚本、数据或前端组件 | 可能重启服务 | P3 |
| `update.sh` | `U` | 下载/写入 | 无 | 脚本更新结果 | 覆盖脚本 | 无 | P3 |
| `reinstall` | 无 | 下载/写入 | 无 | 重装结果 | 覆盖脚本或组件 | 可能重启服务 | P3 |
| `uninstall` | `un` | 删除 | 交互选择 | 卸载结果 | 删除项目管理文件 | 停止/禁用服务 | P3 |
| `start` | 无 | 服务 | 可选 `caddy` | 服务启动结果 | 无 | start Xray/Caddy | P3 |
| `stop` | 无 | 服务 | 可选 `caddy` | 服务停止结果 | 无 | stop Xray/Caddy | P3 |
| `restart` | `r` | 服务 | 可选 `caddy` | 服务重启结果 | 无 | restart Xray/Caddy | P3 |
| `test` | `t` | 只读/验证 | `[xray\|nginx\|certbot\|all]` | 配置、证书、renewal 和服务检查 | 无 | 显式 certbot 目标可运行 renewal dry-run | P1 |
| `log` | 无 | 只读/维护 | 可选动作 | 访问日志 | 可能清理日志 | 无 | P3 |
| `logerr` | `errlog` | 只读/维护 | 可选动作 | 错误日志 | 可能清理日志 | 无 | P3 |
| `dns` | 无 | 写入 | DNS 参数 | 设置结果 | 修改系统 DNS 配置 | 可能影响网络 | P3 |
| `bbr` | 无 | 写入 | 无 | BBR 设置结果 | 写 sysctl 配置 | 可能要求重启 | P3 |
| `ip` | 无 | 网络只读 | 无 | 公网 IP | 无 | 访问外部探测服务 | P3 |
| `get-port` | 无 | 只读 | 无 | 可用随机端口 | 无 | 读取本地端口占用 | P3 |
| `bin` | 无 | passthrough | Xray 原生命令参数 | Xray 输出 | 取决于原生命令 | 取决于原生命令 | P3 |
| `api` | `xapi` | passthrough | Xray API 参数 | Xray API 输出 | 可能变更运行时 | Xray API 热变更 | P3 |
| `run` | `uuid`, `tls`, `convert` | passthrough | Xray 原生命令参数 | Xray 输出 | 取决于原生命令 | 取决于原生命令 | P3 |
| `debug` | 无 | 只读 | 配置名 | 脱敏提醒和配置变量 | 无 | 可能触发 IP 探测 | P3 |
| `help` | `h`, `--help` | 只读 | 可选主题 | 帮助文本 | 无 | 无 | P3 |
| `main` | 无 | 交互 | 菜单选择 | 交互流程 | 取决于选择 | 取决于选择 | P3 |

## 协议输入矩阵

| 协议族 | 快捷输入 | 参数形式 | TLS 前端 | Phase 0 契约重点 |
| --- | --- | --- | --- | --- |
| VMess TCP/mKCP/QUIC | `tcp`, `kcp`, `quic` | `[port] [uuid] [type]` | 否 | `network`、伪装类型、URL。 |
| VMess dynamic-port | `tcpd`, `kcpd`, `quicd` | `[port] [uuid] [type] [start_port] [end_port]` | 否 | detour、link JSON、动态端口范围。 |
| VMess WS/H2/gRPC | `ws`, `h2`, `grpc` | `[host] [uuid] [/path]` | 是 | host/path/TLS URL、前端路由。 |
| VLESS WS/H2/gRPC | `vws`, `vh2`, `vgrpc` | `[host] [uuid] [/path]` | 是 | VLESS URL、path/serviceName。 |
| VLESS XHTTP | `vxhttp` | `[port] [uuid] [host] [path]` | 是 | `xhttpSettings.mode=auto`、host/path。 |
| VLESS REALITY | `r`, `reality` | `[port] [uuid] [servername]` | 否 | `serverName`、`publicKey`、`flow=xtls-rprx-vision`。 |
| Trojan WS/H2/gRPC | `tws`, `th2`, `tgrpc` | `[host] [password] [/path]` | 是 | password URL、TLS 前端路由。 |
| Trojan XHTTP | `txhttp` | `[port] [password] [host] [path]` | 是 | 当前 Mihomo 支持边界和 Xray JSON。 |
| Shadowsocks | `ss` | `[port] [password] [method]` | 否 | method/password、SS URL。 |
| Socks | `socks` | `[port] [username] [password]` | 否 | accounts、socks URL、Mihomo socks5。 |

## 稳定输出字段

Go 迁移中这些字段必须作为稳定契约处理：

- `info`: protocol、address、port、id/password、network、host、path/serviceName、TLS、flow、serverName、fingerprint、publicKey。
- `url`: scheme、server、port、uuid/password、security、type、host、path/serviceName、sni、pbk、flow。
- `gen`: `.inbounds[0].protocol`、`.port`、`.listen`、`.settings`、`.streamSettings`、`.sniffing`。
- `mihomo`: `type`、`server`、`port`、`uuid/password`、`network`、`tls`、`servername/sni`、`reality-opts`、`xhttp-opts`。

颜色、横线、提示语、帮助链接属于可改善的人类输出，但改变前应在测试中避免把它们当作稳定 API。
