# 产品需求文档 (PRD)
## Xray 管理脚本

| 字段 | 值 |
|------|-----|
| **产品名称** | Xray 管理脚本 |
| **版本** | v1.2.0 |
| **作者** | WangYan-Good |
| **仓库地址** | https://github.com/WangYan-Good/xray |
| **最后更新** | 2026-05-05 |
| **状态** | 活跃 |

---

## 1. 产品概述

一个基于 bash 的命令行工具，用于在 Linux 系统上部署、管理和运行 Xray 代理服务器。提供一键安装、多协议配置管理、自动 TLS 证书配置以及 Mihomo/Clash 订阅生成功能。

### 1.1 目标用户

- 管理代理基础设施的系统管理员
- 部署个人代理服务器的普通用户
- 需要快速搭建 Xray 节点、不希望手动编辑 JSON 配置的用户

### 1.2 支持平台

| 操作系统 | 包管理器 |
|----------|----------|
| Ubuntu / Debian | apt-get |
| CentOS | yum |

| 系统架构 |
|----------|
| x86_64 (amd64) |
| ARM64 (aarch64 / armv8) |

---

## 2. 核心功能

### 2.1 安装与部署

| ID | 需求 | 优先级 |
|----|------|--------|
| INST-001 | 一键安装并自动解决依赖（wget、unzip、jq） | P0 |
| INST-002 | 从 GitHub Releases 下载 Xray-core 并进行 SHA256 完整性校验 | P0 |
| INST-003 | 支持通过 `-v` 参数指定核心版本 | P1 |
| INST-004 | 支持通过 `-f` 参数使用本地核心文件 | P1 |
| INST-005 | 支持通过 `-p` 参数配置代理下载 | P1 |
| INST-006 | 支持通过 `-l` 参数本地安装 | P2 |
| INST-007 | 注册 systemd 服务以管理 Xray 生命周期 | P0 |
| INST-008 | 检测已安装版本并提供重新安装/卸载后重装/退出选项 | P1 |
| INST-009 | 通过 `timedatectl set-ntp` 自动同步系统时间 | P1 |
| INST-010 | 配置系统限制（LimitNOFILE=1048576）和日志轮转 | P1 |

### 2.2 协议支持

| ID | 协议 | 优先级 |
|----|------|--------|
| PROTO-001 | VMess-TCP | P0 |
| PROTO-002 | VMess-mKCP | P1 |
| PROTO-003 | VMess-QUIC | P1 |
| PROTO-004 | VMess-H2-TLS | P1 |
| PROTO-005 | VMess-WS-TLS | P0 |
| PROTO-006 | VMess-gRPC-TLS | P1 |
| PROTO-007 | VLESS-H2-TLS | P1 |
| PROTO-008 | VLESS-WS-TLS | P0 |
| PROTO-009 | VLESS-gRPC-TLS | P1 |
| PROTO-010 | VLESS-XHTTP-TLS | P0 |
| PROTO-011 | VLESS-XTLS-uTLS-REALITY | P0 |
| PROTO-012 | Trojan-H2-TLS | P1 |
| PROTO-013 | Trojan-WS-TLS | P1 |
| PROTO-014 | Trojan-gRPC-TLS | P1 |
| PROTO-015 | Trojan-XHTTP-TLS | P1 |
| PROTO-016 | Shadowsocks | P0 |
| PROTO-017 | Socks | P2 |
| PROTO-018 | 动态端口（VMess-TCP/mKCP/QUIC） | P2 |

### 2.3 配置管理

| ID | 需求 | 优先级 |
|----|------|--------|
| CFG-001 | 通过交互式菜单或命令行参数添加配置 | P0 |
| CFG-002 | 查看配置详情（协议、地址、端口、UUID、路径、TLS、URL 等） | P0 |
| CFG-003 | 按名称删除配置（直接删除，无需确认） | P0 |
| CFG-004 | 批量删除多个配置（`ddel`） | P1 |
| CFG-005 | 修改协议、端口、域名、路径、密码、UUID、加密方式、伪装类型、目标地址、目标端口、密钥对、SNI、动态端口、伪装网站、mKCP seed、用户名 | P0 |
| CFG-006 | 自动生成随机值（UUID、端口、路径、密码、加密方式） | P1 |
| CFG-007 | 修复单个或多个配置文件（`fix`、`fix-all`） | P1 |
| CFG-008 | 输入格式校验（数字、端口、域名、路径、UUID） | P0 |
| CFG-009 | 输出客户端 JSON 用于测试（`client`、`genc`、`gen`） | P1 |

### 2.4 TLS 证书管理

| ID | 需求 | 优先级 |
|----|------|--------|
| TLS-001 | 支持 Caddy 作为 TLS 方案（自动 HTTPS，配置简洁） | P0 |
| TLS-002 | 支持 Nginx + Certbot 作为 TLS 方案（灵活，多站点共存） | P0 |
| TLS-003 | 自动检测已安装的 Caddy/Nginx 并提示用户选择 | P1 |
| TLS-004 | 防止 Caddy 和 Nginx 同时运行时的端口冲突 | P0 |
| TLS-005 | 自动为各传输协议（ws/grpc/xhttp/h2）配置反向代理规则 | P0 |
| TLS-006 | 允许跳过自动 TLS（`no-auto-tls`），适用于手动证书场景 | P1 |
| TLS-007 | 修复 Caddyfile 或 Nginx 配置（`fix-caddyfile`、`fix-nginxfile`） | P1 |

### 2.5 Mihomo/Clash 订阅

| ID | 需求 | 优先级 |
|----|------|--------|
| SUB-001 | 从所有配置生成 Mihomo 兼容的 YAML 订阅 | P0 |
| SUB-002 | 支持通过配置文件路径指定单个目标生成订阅 | P1 |
| SUB-003 | 订阅接口基于 Token 认证 | P0 |
| SUB-004 | 自动在 Caddy 或 Nginx 中配置 HTTP 路由 | P0 |
| SUB-005 | 显示订阅 URL（`sub-url`） | P0 |
| SUB-006 | 刷新订阅文件并更新 Web 服务器配置（`refresh-sub`） | P0 |

### 2.6 服务管理

| ID | 需求 | 优先级 |
|----|------|--------|
| SVC-001 | 启动 / 停止 / 重启 Xray 服务 | P0 |
| SVC-002 | 启动 / 停止 / 重启 Caddy 或 Nginx | P1 |
| SVC-003 | 查看运行状态（`status`） | P0 |
| SVC-004 | 测试配置有效性（`test`） | P0 |
| SVC-005 | 查看访问日志和错误日志（`log`、`logerr`） | P0 |

### 2.7 更新与维护

| ID | 需求 | 优先级 |
|----|------|--------|
| UPD-001 | 更新 Xray-core 至最新版或指定版本 | P0 |
| UPD-002 | 更新管理脚本至最新版 | P0 |
| UPD-003 | 更新 geoip.dat 和 geosite.dat（Loyalsoldier 规则库） | P1 |
| UPD-004 | 更新 Caddy 至最新版 | P1 |
| UPD-005 | 通过包管理器重新安装 Nginx + Certbot | P1 |
| UPD-006 | 更新脚本自身（`update.sh`） | P0 |

### 2.8 卸载

| ID | 需求 | 优先级 |
|----|------|--------|
| UN-001 | 删除所有 Xray 文件（脚本、核心、配置、日志、systemd 服务） | P0 |
| UN-002 | 清理 bashrc 别名和命令链接 | P0 |
| UN-003 | 可选：停止并移除 Caddy | P1 |
| UN-004 | 可选：停止并移除 Nginx | P1 |

### 2.9 辅助工具

| ID | 需求 | 优先级 |
|----|------|--------|
| UTIL-001 | 启用 BBR 拥塞控制（如系统支持） | P2 |
| UTIL-002 | 配置 DNS 设置 | P1 |
| UTIL-003 | 生成配置的二维码 | P1 |
| UTIL-004 | 生成可分享的配置 URL | P1 |
| UTIL-005 | 显示当前脚本和核心版本 | P0 |
| UTIL-006 | 获取服务器公网 IP | P1 |
| UTIL-007 | 获取一个可用的随机端口 | P2 |
| UTIL-008 | 运行原生 Xray 二进制命令（`bin`） | P1 |

---

## 3. 非功能性需求

### 3.1 安全性

| ID | 需求 | 优先级 |
|----|------|--------|
| SEC-001 | 安装过程要求 root 权限 | P0 |
| SEC-002 | Xray-core 和 Caddy 下载需进行 SHA256 校验 | P0 |
| SEC-003 | 订阅接口基于 Token 访问控制 | P0 |
| SEC-004 | 所有下载强制使用 TLS 1.2+ | P0 |
| SEC-005 | Token 文件权限设置为 600 | P1 |
| SEC-006 | 订阅文件权限设置为 644 | P1 |

### 3.2 可靠性

| ID | 需求 | 优先级 |
|----|------|--------|
| REL-001 | 下载失败时自动重试 3-5 次 | P0 |
| REL-002 | 安装失败时回滚已部署的文件 | P0 |
| REL-003 | 绑定前校验端口可用性（netstat/ss 降级兼容） | P1 |
| REL-004 | 端口随机化自动重试最多 233 次 | P1 |

### 3.3 可维护性

| ID | 需求 | 优先级 |
|----|------|--------|
| MAINT-001 | 通过 ShellCheck 静态分析（severity=warning，排除规则已在 CI 中记录） | P0 |
| MAINT-002 | 通过 `bash -n` 语法校验所有 `.sh` 文件 | P0 |
| MAINT-003 | 所有 `.json` 文件必须为合法 JSON 格式 | P0 |
| MAINT-004 | 源代码中无 V2Ray/v2ray 残留（除合法上下文外） | P0 |
| MAINT-005 | `protocol_list` 中必须包含所有必需协议 | P0 |

### 3.4 性能

| ID | 需求 | 优先级 |
|----|------|--------|
| PERF-001 | 顺序下载以避免竞态条件 | P1 |
| PERF-002 | 非阻塞操作（包安装、服务重启）使用后台执行 | P2 |

---

## 4. 架构设计

### 4.1 目录结构

```
/etc/xray/
├── bin/                    # Xray-core 二进制及地理数据
│   ├── xray
│   ├── geoip.dat
│   └── geosite.dat
├── conf/                   # 各配置的 JSON 文件
│   ├── vmess-ws-tls.json
│   ├── vless-reality.json
│   └── ...
├── sh/                     # 管理脚本
│   ├── src/
│   │   ├── core.sh         # 核心逻辑（协议、配置、菜单）
│   │   ├── caddy.sh        # Caddy TLS 方案
│   │   ├── nginx.sh        # Nginx TLS 方案
│   │   ├── mihomo.sh       # Mihomo/Clash 订阅生成器
│   │   ├── download.sh     # 下载与更新逻辑
│   │   ├── help.sh         # 帮助文档
│   │   ├── dns.sh          # DNS 配置
│   │   ├── bbr.sh          # BBR 拥塞控制
│   │   ├── init.sh         # 初始化及共享工具函数
│   │   ├── systemd.sh      # systemd 服务管理
│   │   └── log.sh          # 日志轮转配置
│   └── xray.sh             # 入口脚本
└── config.json             # 主 Xray 配置（自动生成）

/etc/caddy/                 # Caddy 配置（如选择该方案）
/etc/nginx/                 # Nginx 配置（如选择该方案）
/var/log/xray/              # 日志目录
/usr/local/bin/xray         # 命令软链接 -> /etc/xray/sh/xray.sh
```

### 4.2 模块依赖关系

```
install.sh
  └── download.sh（包安装、文件下载）
  └── init.sh（共享变量、消息、错误输出）

xray.sh（入口）
  └── init.sh（加载共享函数）
      └── core.sh（主菜单、添加/修改/删除/查看）
          ├── caddy.sh（通过 Caddy 提供 TLS）
          ├── nginx.sh（通过 Nginx 提供 TLS）
          ├── mihomo.sh（订阅生成）
          ├── download.sh（更新）
          ├── help.sh（帮助输出）
          ├── dns.sh（DNS）
          ├── bbr.sh（BBR）
          ├── systemd.sh（服务管理）
          └── log.sh（日志轮转）
```

---

## 5. 命令行接口

### 5.1 安装参数

```
install.sh [-f <文件>] [-l] [-p <代理>] [-v <版本>] [--tls <caddy|nginx>] [--uninstall] [-h]
```

### 5.2 运行时命令

```
xray <命令> [参数...]

基础:
  v, version                        显示当前版本
  ip                                返回服务器公网 IP
  get-port                          返回一个可用端口

常用:
  a, add [协议] [参数...|auto]      添加配置
  c, change [名称] [选项] [参数]    修改配置
  d, del [名称]                     删除配置
  i, info [名称]                    查看配置详情
  qr [名称]                         输出二维码
  url [名称]                        输出可分享 URL
  mihomo, clash [名称]              输出 Mihomo YAML 订阅
  refresh-sub [域名]                刷新订阅文件及 HTTP 入口
  sub-url [域名]                    显示订阅 URL
  log                               查看访问日志
  logerr                            查看错误日志

修改:
  dp, dynamicport [名称] ...        修改动态端口范围
  full [名称] [...]                 修改多个参数
  id [名称] [uuid|auto]             修改 UUID
  host [名称] [域名]                修改域名/host
  port [名称] [端口|auto]           修改端口
  path [名称] [路径|auto]           修改路径
  passwd [名称] [密码|auto]         修改密码
  type [名称] [类型|auto]           修改伪装类型
  method [名称] [方式|auto]         修改加密方式
  seed [名称] [seed|auto]           修改 mKCP seed
  new [名称] [...]                  修改协议
  web [名称] [域名]                 修改伪装网站

高级:
  dns [...]                         配置 DNS
  dd, ddel [名称...]                删除多个配置
  fix [名称]                        修复单个配置文件
  fix-all                           修复所有配置文件
  fix-caddyfile                     修复 Caddyfile
  fix-nginxfile                     修复 Nginx 配置
  fix-config.json                   修复主配置文件

管理:
  un, uninstall                     卸载所有内容
  u, update [组件] [版本]           更新指定组件
  U, update.sh                      更新管理脚本
  s, status                         显示运行状态
  start, stop, restart [服务]       服务控制
  t, test                           测试配置
  reinstall                         重新安装脚本

测试:
  client [名称]                     输出客户端 JSON
  debug [名称]                      输出调试信息
  gen [...]                         生成 JSON 但不创建文件
  genc [名称]                       输出客户端部分 JSON
  no-auto-tls [...]                 添加配置但禁止自动 TLS
  xapi [...]                        API 后端使用当前运行的 Xray 服务

其他:
  bbr                               启用 BBR（如支持）
  bin [...]                         运行原生 Xray 命令
  api, convert, tls, run, uuid      兼容 Xray 原生命令
  h, help                           显示帮助信息
```

---

## 6. 错误码

| 编码 | 名称 | 描述 |
|------|------|------|
| 1 | ERR_DOWNLOAD | 下载失败（核心、脚本、jq） |
| 2 | ERR_CHECKSUM | SHA256 校验和不匹配 |
| 3 | ERR_PERMISSION | 非 root 用户尝试安装 |
| 4 | ERR_ARCH | 不支持的系统架构（非 x86_64 或 ARM64） |
| 5 | ERR_DEPENDENCY | 缺少系统依赖（apt/yum、systemctl 等） |
| 6 | ERR_CERT | TLS 证书配置失败 |
| 7 | ERR_CONFIG | 配置或安装过程出错 |
| 8 | ERR_SERVICE | systemd 服务管理失败 |

---

## 7. CI/CD 流水线

| 任务 | 触发条件 | 检查项 |
|------|----------|--------|
| **ShellCheck** | push 至 develop/main/master，PR 至 develop/main/master | 对所有 `.sh` 文件进行静态分析（排除 core.sh），排除规则已记录 |
| **Bash 语法校验** | push 至 develop/main/master，PR 至 develop/main/master | 对所有 `.sh` 文件执行 `bash -n` 语法验证 |
| **自动化测试用例** | push 至 develop/main/master，PR 至 develop/main/master，手动触发 | 执行 `tests/run.sh`，覆盖脚本化 `testcase-*.sh` 流程、发布打包契约、协议契约和关键部署回归保护 |
| **JSON 格式校验** | push 至 develop/main/master，PR 至 develop/main/master | 所有 `.json` 文件必须能被 `jq` 正常解析 |
| **命名一致性** | push 至 develop/main/master，PR 至 develop/main/master | 源代码中无 V2Ray/v2ray 残留（除允许的上下文外） |
| **协议完整性** | push 至 develop/main/master，PR 至 develop/main/master | `protocol_list` 中必须包含全部 8 个必需协议 |

---

## 8. 外部依赖

| 依赖 | 来源 | 用途 |
|------|------|------|
| Xray-core | github.com/XTLS/Xray-core | 核心代理引擎 |
| jq | github.com/jqlang/jq | JSON 解析和生成 |
| geoip.dat / geosite.dat | github.com/Loyalsoldier/v2ray-rules-dat | GeoIP 和 GeoSite 路由规则 |
| Caddy（可选） | github.com/caddyserver/caddy | 自动 TLS 证书配置 |
| Nginx（可选） | apt/yum 包管理器 | 反向代理 + Certbot TLS |
| Certbot（可选） | apt/yum 包管理器 | Let's Encrypt 证书管理 |

---

## 9. 术语表

| 术语 | 定义 |
|------|------|
| **Xray** | 支持多协议的高性能代理核心 |
| **Mihomo / Clash** | 兼容 YAML 订阅格式的代理客户端软件 |
| **TLS** | 传输层安全协议，用于加密连接 |
| **REALITY** | Xray 的 TLS 指纹绕过技术 |
| **XHTTP** | Xray 的扩展 HTTP 传输协议 |
| **BBR** | Google 的 TCP 拥塞控制算法 |
| **UUID** | 通用唯一标识符，用于 VMess/VLESS 的用户身份识别 |
