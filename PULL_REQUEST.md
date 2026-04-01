# Pull Request: 集成 Nginx + Certbot 自动配置功能到 v2ray add 命令

## PR 信息

- **标题**: feat: 集成 Nginx + Certbot 自动配置功能到 v2ray add 命令
- **分支**: `feature/oneclick-nginx-cert` → `develop`
- **提交**: `7c745f2`

## 变更摘要

### 新增功能

1. **一键配置 Nginx + Certbot**
   - 添加配置时自动检测并使用 Nginx + Certbot
   - 自动生成 Nginx 站点配置文件
   - 自动申请和管理 TLS 证书
   - 自动验证 Nginx 配置并重载服务

2. **Web 服务器选择**
   - 交互式选择：Caddy (默认) 或 Nginx + Certbot
   - 非交互式选择：使用环境变量 `V2RAY_WEB_SERVER=nginx`

3. **环境变量支持**
   - `V2RAY_WEB_SERVER=nginx`: 使用 Nginx + Certbot
   - `V2RAY_WEB_SERVER=caddy`: 使用 Caddy (默认)

### 修改内容

#### 1. 核心文件修改

| 文件 | 变更描述 |
|------|----------|
| `src/lib/core/core.sh` | 集成 Nginx 配置流程到 `add()` 函数 |
| `src/nginx.sh` | 添加 `nginx_config()`, `nginx_certbot()`, `nginx_reload()`, `nginx_test()` 函数 |
| `src/init.sh` | 添加 `V2RAY_WEB_SERVER` 环境变量支持 |
| `scripts/install.sh` | 添加 Nginx 一键安装功能 |
| `scripts/v2ray.sh` | 修复兼容性 stub 脚本 |

#### 2. 新增模块

| 模块 | 文件 | 功能 |
|------|------|------|
| 错误处理框架 | `src/lib/common/error.sh`, `src/lib/utils/error_handler.sh` | 统一错误处理机制 |
| 日志管理 | `src/lib/common/log.sh`, `src/lib/utils/log.sh` | 统一日志输出 |
| 模块加载器 | `src/lib/common/module_loader.sh` | 动态模块加载 |
| 初始化工具 | `src/lib/common/init.sh` | 环境初始化 |

#### 3. 文档更新

| 文件 | 变更描述 |
|------|----------|
| `TEST_REPORT.md` | 添加集成测试报告 |
| `docs/ERROR_CODES.md` | 添加错误代码文档 |
| `scripts/rollback-arch.sh` | 添加架构.rollback 脚本 |

### 技术实现

#### Nginx 配置流程

```
用户执行: v2ray add vmess-ws-tls example.com
    │
    ▼
检测 Web 服务器 (优先使用 Nginx)
    │
    ▼
生成 Nginx 配置: /etc/nginx/v2ray/VMess-WS-example.com.conf
    │
    ▼
申请 TLS 证书 (Certbot)
    │
    ├─► 检查现有证书
    ├─► 首次申请: standalone 模式
    └─► 续期: webroot 模式
    │
    ▼
验证 Nginx 配置: nginx -t
    │
    ▼
重载 Nginx: systemctl reload nginx
    │
    ▼
显示配置信息
```

#### 关键函数

| 函数 | 描述 |
|------|------|
| `nginx_config()` | 生成 Nginx 站点配置文件 |
| `nginx_certbot()` | 申请和管理 TLS 证书 |
| `nginx_reload()` | 重载或启动 Nginx |
| `nginx_test()` | 验证 Nginx 配置 |

### 支持的协议

以下协议添加时自动配置 Nginx + TLS:

| 协议 | 传输方式 | TLS | 说明 |
|------|----------|-----|------|
| VMess | WS/H2/gRPC | ✅ | VMess + Nginx + TLS |
| VLESS | WS/H2/gRPC | ✅ | VLESS + Nginx + TLS |
| Trojan | WS/H2/gRPC | ✅ | Trojan + Nginx + TLS |

### 兼容性

- ✅ 向后兼容：现有 Caddy 用户不受影响
- ✅ 无缝升级：支持从 Caddy 迁移到 Nginx
- ✅ 混合部署：支持 Caddy 和 Nginx 共存

### 测试结果

- ✅ 代码语法检查通过
- ✅ 单元测试通过
- ✅ VPS 集成测试通过
- ✅ Nginx 1.20.1 + Certbot 3.1.0 验证通过

### 已知问题

1. **IS_SH_VER 未定义** (不影响功能)
   - 位置: `src/lib/core/core.sh:2641`
   - 描述: `update()` 函数中引用了未定义的变量
   - 影响: 仅在运行 `v2ray add` 时显示警告
   - 状态: already-existing 问题，后续版本修复

## 使用示例

### 交互式安装（推荐）

```bash
# 下载并安装
wget -O install.sh https://github.com/WangYan-Good/v2ray/releases/latest/download/install.sh
chmod +x install.sh
./install.sh

# 选择: 2) Nginx + Certbot

# 添加配置（自动配置 Nginx + TLS）
v2ray add vmess-ws-tls example.com
```

### 非交互式安装

```bash
# 使用环境变量
V2RAY_WEB_SERVER=nginx ./install.sh

# 或使用参数
./install.sh --tls nginx
```

### 批量部署

```bash
# 批量添加多个配置
v2ray add vmess-ws-tls site1.com
v2ray add vless-grpc-tls site2.com
v2ray add trojan-ws-tls site3.com
```

## 文档更新

### README.md

- 添加 Nginx + Certbot 一键配置说明
- 更新安装指南
- 添加使用示例

### 故障排除

- 添加常见问题解决方案
- 添加错误代码说明
- 添加快速诊断命令

## 检查清单

- [x] 代码符合规范
- [x] 错误处理完善
- [x] 测试通过
- [x] 文档更新
- [x] 向后兼容
- [x] VPS 集成测试通过

## 相关 Issues

- N/A

## 附录

### 迁移指南

从 Caddy 迁移到 Nginx:

```bash
# 卸载 Caddy
v2ray uninstall-caddy

# 安装 Nginx
v2ray install-nginx

# 重新添加配置
v2ray del <old_config>
v2ray add vmess-ws-tls example.com
```

### 技术细节

#### 文件结构

```
/etc/nginx/
├── nginx.conf              # 主配置
├── ssl/                    # SSL 证书
│   └── example.com/ -> /etc/letsencrypt/live/example.com
└── v2ray/                  # V2Ray 站点配置
    ├── VMess-WS-example.com.conf
    ├── VLESS-GRPC-grpc.example.com.conf
    └── Trojan-WS-trojan.example.com.conf
```

#### 证书管理

- 位置: `/etc/letsencrypt/live/${DOMAIN}/`
- 软链接: `/etc/nginx/ssl/${DOMAIN}/`
- 续期: Certbot 自动续期

## 作者

WangYan-Good

## 日期

2026-04-01
