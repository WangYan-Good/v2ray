# V2Ray 脚本完整文档

> 一个支持多站点共存的 V2Ray 一键安装和管理脚本

> **本项目 Fork 自**: [233boy/v2ray](https://github.com/233boy/v2ray)  
> **主要改进**: 添加 Nginx + Certbot 多站点共存支持

---

## 目录

1. [项目概述](#项目概述)
2. [架构设计](#架构设计)
3. [安装指南](#安装指南)
4. [使用指南](#使用指南)
5. [Nginx 多站点配置](#nginx-多站点配置)
6. [配置参考](#配置参考)
7. [故障排查](#故障排查)
8. [常见问题](#常见问题)
9. [Cloudflare 代理配置](#cloudflare-代理配置)

---

## 项目概述

### 简介

这是一个 **V2Ray 一键安装脚本和管理脚本**，支持两种 TLS 方案：
- **Caddy** - 简洁易用，适合单站点
- **Nginx + Certbot** - 灵活强大，适合多站点共存

### 设计理念

- **高效率** - 添加配置仅需不到 1 秒
- **超快速** - 自动化所有流程
- **极易用** - 零学习成本
- **多配置并发** - 支持同时运行多个协议配置

### 支持的协议

| 协议 | 传输方式 | TLS | 动态端口 | 说明 |
|------|----------|-----|----------|------|
| VMess | TCP/mKCP/QUIC | ❌ | ✅ | 基础协议 |
| VMess | WS/H2/gRPC | ✅ | ❌ | 推荐组合 |
| VLESS | WS/H2/gRPC | ✅ | ❌ | 新一代协议 |
| Trojan | WS/H2/gRPC | ✅ | ❌ | 伪装性强 |
| Shadowsocks | TCP | ❌ | ❌ | 简单快速 |
| Socks | TCP | ❌ | ❌ | 代理协议 |

---

## 架构设计

### 目录结构

```
/etc/v2ray/
├── bin/                    # V2Ray 核心二进制
│   ├── v2ray
│   ├── geoip.dat
│   └── geosite.dat
├── sh/                     # 脚本源码
│   ├── src/
│   │   ├── init.sh         # 初始化
│   │   ├── core.sh         # 核心逻辑
│   │   ├── nginx.sh        # Nginx 配置
│   │   ├── caddy.sh        # Caddy 配置
│   │   ├── systemd.sh      # 服务管理
│   │   ├── download.sh     # 下载工具
│   │   ├── help.sh         # 帮助信息
│   │   ├── log.sh          # 日志管理
│   │   ├── dns.sh          # DNS 配置
│   │   └── bbr.sh          # BBR 优化
│   └── v2ray.sh            # 主入口
├── conf/                   # V2Ray 配置文件
│   ├── VMess-WS-8080.json
│   └── VLESS-gRPC-443.json
└── config.json             # 主配置文件

/etc/nginx/                 # Nginx 方案目录
├── nginx.conf              # 主配置
├── ssl/                    # SSL 证书
│   └── 域名/
├── v2ray/                  # V2Ray 站点配置
│   └── 域名.conf
└── sites-enabled/          # 其他站点配置

/etc/caddy/                 # Caddy 方案目录
├── Caddyfile               # 主配置
└── v2ray/                  # V2Ray 站点配置
    └── 域名.conf
```

### 核心模块

| 模块 | 文件 | 功能 |
|------|------|------|
| 初始化 | `init.sh` | 环境变量、状态检测、模块加载 |
| 核心逻辑 | `core.sh` | 添加/更改/删除配置、API 操作 |
| Nginx | `nginx.sh` | Nginx 配置生成、Certbot 证书管理 |
| Caddy | `caddy.sh` | Caddy 配置生成、自动 TLS |
| 服务管理 | `systemd.sh` | systemd 服务定义 |
| 下载 | `download.sh` | 核心/脚本/Caddy/Nginx 下载安装 |

### 数据流

```
用户命令 (v2ray xxx)
    │
    ▼
v2ray.sh (入口)
    │
    ▼
init.sh (初始化)
    │
    ├─► 检测 V2Ray 状态
    ├─► 检测 Caddy 状态
    ├─► 检测 Nginx 状态
    │
    ▼
core.sh (核心逻辑)
    │
    ├─► add    ──► create() ──► nginx.sh / caddy.sh
    ├─► change ──► modify() ──► nginx.sh / caddy.sh
    ├─► del    ──► remove()  ──► nginx.sh / caddy.sh
    └─► info   ──► read()
```

---

## 安装指南

### 系统要求

- **操作系统**: Ubuntu 18.04+ / Debian 10+ / CentOS 7+
- **架构**: x86_64 (64 位) 或 ARM64
- **权限**: ROOT 用户
- **端口**: 80 和 443 未被占用（TLS 方案需要）

### 快速安装

```bash
# 下载安装脚本
wget -O install.sh https://github.com/WangYan-Good/v2ray/releases/latest/download/install.sh
chmod +x install.sh

# 执行安装（交互式选择 TLS 方案，带详细步骤日志）
./install.sh

# 或指定 TLS 方案（非交互式）
./install.sh --tls nginx   # 使用 Nginx（推荐多站点）
./install.sh --tls caddy   # 使用 Caddy（适合单站点）

# 卸载（带详细步骤日志）
./install.sh --uninstall
```

### 更新已安装的脚本

如果已安装旧版本脚本，使用以下方法更新：

**方式 1：使用 update.sh 命令（推荐）**
```bash
v2ray update.sh
```

**方式 2：重新安装**
```bash
# 1. 卸载旧版本
./install.sh --uninstall

# 2. 重新安装
./install.sh --tls nginx
```

**方式 3：手动更新（保留配置）**
```bash
# 1. 复制最新脚本到安装目录
cp -rf /path/to/v2ray/src/* /etc/v2ray/sh/src/

# 2. 复制主脚本
cp /path/to/v2ray/v2ray.sh /etc/v2ray/sh/

# 3. 验证版本
v2ray version
```

### 安装过程示例

```
[步骤 1/10] 准备安装环境...
  - 本地获取安装脚本
  - 安装环境准备完成
[步骤 2/10] 同步系统时间...
  - 系统时间已同步
[步骤 3/10] 安装依赖包...
  - 依赖包安装进行中 (后台)
[步骤 4/10] 检查 jq...
  - jq 已安装
[步骤 5/10] 下载必要文件...
  - 开始下载 V2Ray 核心
  - 开始下载脚本
  - 已获取服务器 IP
[步骤 6/10] 等待下载完成...
  - 所有文件下载完成
[步骤 7/10] 检查下载状态...
  - 所有文件检查通过
[步骤 8/10] 测试核心文件...
  - 核心文件测试通过
[步骤 9/10] 获取服务器 IP...
  - 服务器 IP: x.x.x.x
[步骤 10/10] 安装文件到系统...
  - 已创建脚本目录
  - 已解压脚本文件
  - 已创建核心目录
  - 已解压核心文件
  - 已添加别名
  - 已创建命令链接
  - 已设置执行权限
  - 已创建日志目录
```

### 卸载过程示例

```
开始卸载 V2Ray 和相关组件...
[步骤 1/6] 删除 V2Ray 文件...
  - 已删除 /etc/v2ray
  - 已删除 /var/log/v2ray
  - 已删除 /usr/local/bin/v2ray
[步骤 2/6] 清理 bashrc 配置...
  - 已清理 /root/.bashrc
[步骤 3/6] 检测到 Caddy，停止并卸载...
  - 已停止 Caddy 服务
  - 已禁用 Caddy 服务
  - 已删除 Caddy 文件
[步骤 4/6] 检测到 Nginx，停止并卸载...
  - 已停止 Nginx 服务
  - 已禁用 Nginx 服务
  - 已删除 Nginx 文件
[步骤 5/6] 清理 systemd 配置...
  - 已重载 systemd 配置
[步骤 6/6] 卸载完成!
```

### 安装参数

```bash
# 自定义 V2Ray 版本
./install.sh -v v5.10.0

# 使用代理下载
./install.sh -p http://127.0.0.1:2333

# 本地安装（使用当前目录脚本）
./install.sh -l

# 自定义核心文件
./install.sh -f /root/v2ray-linux-64.zip

# 选择 TLS 方案
./install.sh --tls nginx   # Nginx + Certbot（多站点共存）
./install.sh --tls caddy   # Caddy（单站点简洁）
```

### TLS 方案选择

安装脚本支持两种 TLS 方案，并**智能检测已安装的服务**：

**交互式选择**（默认）：

脚本会自动检测已安装的 Web 服务，并提供相应的选项：

#### 场景 1：Caddy 和 Nginx 都已安装

```
选择 TLS 配置方案:
检测到 Caddy 和 Nginx 都已安装，请选择:
1) 使用 Caddy
2) 使用 Nginx
3) 停止 Caddy，使用 Nginx
4) 停止 Nginx，使用 Caddy
请输入选择 [1-4] (默认:2):
```

#### 场景 2：仅 Caddy 已安装

```
选择 TLS 配置方案:
检测到 Caddy 已安装，请选择:
1) 使用 Caddy (默认)
2) 停止 Caddy，改用 Nginx
请输入选择 [1-2] (默认:1):
```

#### 场景 3：仅 Nginx 已安装

```
选择 TLS 配置方案:
检测到 Nginx 已安装，请选择:
1) 使用 Nginx (默认)
2) 停止 Nginx，改用 Caddy
请输入选择 [1-2] (默认:1):
```

#### 场景 4：都未安装（全新系统）

```
选择 TLS 配置方案:
1) Caddy (简洁，适合单站点)
2) Nginx + Certbot (灵活，适合多站点共存) (默认)
请输入选择 [1-2] (默认:2):
```

**命令行指定**（跳过交互）：
```bash
./install.sh --tls nginx   # 使用 Nginx
./install.sh --tls caddy   # 使用 Caddy
```

### 已部署站点的兼容安装

脚本会自动检测并兼容现有的 Web 服务：

#### Nginx 已安装

如果主机已安装 Nginx，脚本会：
- ✅ 使用现有 Nginx
- ✅ 使用现有 Certbot（如果已安装）
- ✅ 备份现有 `nginx.conf` 到 `nginx.conf.bak`
- ✅ 在现有配置中添加 `include` 导入 V2Ray 配置

```bash
# 直接安装，脚本自动检测
./install.sh --tls nginx

# 输出示例:
# 05:30:17) 检测到 Nginx 已安装，使用现有 Nginx
# 05:30:18) 检测到 Certbot 已安装，使用现有 Certbot
# 05:30:18) 已备份现有 nginx.conf 到 /etc/nginx/nginx.conf.bak
```

#### Caddy 已安装

如果主机已安装 Caddy，脚本会：
- ✅ 使用现有 Caddy
- ✅ 不覆盖现有 Caddyfile
- ✅ 在现有配置基础上添加 import

```bash
# 直接安装，脚本自动检测
./install.sh --tls caddy

# 输出示例:
# 05:30:17) 检测到 Caddy 已安装，使用现有 Caddy
```

#### Nginx 已安装但想使用 Caddy

如果主机已安装 Nginx，但想改用 Caddy 部署 V2Ray：

**方案 1：停止 Nginx 并安装 Caddy（推荐）**

```bash
# 1. 停止 Nginx
systemctl stop nginx
systemctl disable nginx

# 2. 备份 Nginx 配置（可选）
cp -rf /etc/nginx /etc/nginx.bak

# 3. 安装 Caddy + V2Ray
./install.sh --tls caddy

# 输出示例:
# 05:30:17) 配置 Caddy...
# 05:30:18) 检测到 Caddy 已安装，使用现有 Caddy
```

**方案 2：Nginx 和 Caddy 共存（不同域名）**

如果 Nginx 和 Caddy 服务不同域名，可以共存：

```bash
# Nginx 服务 domain1.com
# Caddy 服务 domain2.com

# 1. 修改 Nginx 配置，只监听 domain1.com
# 编辑 /etc/nginx/nginx.conf 或 /etc/nginx/sites-enabled/domain1.com.conf
server {
    listen 80;
    server_name domain1.com;
    # ... 其他配置
}

# 2. 安装 Caddy
./install.sh --tls caddy

# 3. Caddy 会自动处理 domain2.com 的 TLS
# 两个服务共享 80/443 端口（通过 server_name 区分）
```

**方案 3：Nginx 使用非标准端口**

```bash
# 1. 修改 Nginx 使用非标准端口
# 编辑 /etc/nginx/nginx.conf
http {
    server {
        listen 8080;  # 改为 8080
        listen 8443 ssl;  # 改为 8443
        server_name example.com;
        # ... 其他配置
    }
}

# 2. 重启 Nginx
systemctl restart nginx

# 3. 安装 Caddy（使用标准端口）
./install.sh --tls caddy
```

**方案 4：完全迁移到 Caddy**

```bash
# 1. 备份 Nginx 配置
cp -rf /etc/nginx /root/nginx_backup

# 2. 停止并卸载 Nginx
systemctl stop nginx
systemctl disable nginx
rm -rf /etc/nginx /lib/systemd/system/nginx.service

# 3. 安装 Caddy + V2Ray
./install.sh --tls caddy

# 4. 将原有 Nginx 站点迁移到 Caddy
# 例如：原有 Nginx 配置
# server {
#     listen 443 ssl;
#     server_name example.com;
#     ssl_certificate /etc/nginx/ssl/example.com/fullchain.pem;
#     ssl_certificate_key /etc/nginx/ssl/example.com/privkey.pem;
#     location / {
#         proxy_pass http://127.0.0.1:8080;
#     }
# }

# 对应 Caddy 配置：
cat > /etc/caddy/Caddyfile << 'EOF'
example.com {
    tls /etc/caddy/ssl/example.com.crt /etc/caddy/ssl/example.com.key
    reverse_proxy / 127.0.0.1:8080
}
EOF

# 5. 复制证书（如果需要）
mkdir -p /etc/caddy/ssl/example.com
cp /etc/nginx/ssl/example.com/* /etc/caddy/ssl/example.com/

# 6. 重启 Caddy
systemctl restart caddy
```

---

#### Caddy 已安装但想使用 Nginx

如果主机已安装 Caddy，但想改用 Nginx 部署 V2Ray：

**方案 1：停止 Caddy 并安装 Nginx（推荐）**

```bash
# 1. 停止 Caddy
systemctl stop caddy
systemctl disable caddy

# 2. 备份 Caddy 配置（可选）
cp -rf /etc/caddy /etc/caddy.bak

# 3. 安装 Nginx + Certbot
./install.sh --tls nginx

# 输出示例:
# 05:30:17) 配置 Nginx + Certbot...
# 05:30:20) 检测到 Nginx 已安装，使用现有 Nginx
# 05:30:21) 检测到 Certbot 已安装，使用现有 Certbot
```

**方案 2：Caddy 和 Nginx 共存（不同域名）**

如果 Caddy 和 Nginx 使用不同域名，可以共存：

```bash
# Caddy 继续服务 domain1.com
# Nginx 服务 domain2.com

# 1. 修改 Caddy 配置，只监听 domain1.com
cat > /etc/caddy/Caddyfile << 'EOF'
domain1.com {
    reverse_proxy / 127.0.0.1:8080
}
EOF

# 2. 安装 Nginx
./install.sh --tls nginx

# 3. Nginx 配置会自动处理 domain2.com
# 两个服务共享 80/443 端口（通过 server_name 区分）
```

**方案 3：Caddy 使用非标准端口**

```bash
# 1. 修改 Caddy 使用非标准端口
cat > /etc/caddy/Caddyfile << 'EOF'
{
    http_port 8080
    https_port 8443
}

example.com {
    reverse_proxy / 127.0.0.1:3000
}
EOF

# 2. 重启 Caddy
systemctl restart caddy

# 3. 安装 Nginx（使用标准端口）
./install.sh --tls nginx
```

**方案 4：完全迁移到 Nginx**

```bash
# 1. 备份 Caddy 配置
cp -rf /etc/caddy /root/caddy_backup

# 2. 停止并卸载 Caddy
systemctl stop caddy
systemctl disable caddy
rm -rf /etc/caddy /usr/local/bin/caddy /lib/systemd/system/caddy.service

# 3. 安装 Nginx + V2Ray
./install.sh --tls nginx

# 4. 将原有 Caddy 站点迁移到 Nginx
# 例如：原有 Caddy 配置
# example.com { reverse_proxy / 127.0.0.1:8080 }

# 对应 Nginx 配置：
cat > /etc/nginx/sites-enabled/example.com.conf << 'EOF'
server {
    listen 80;
    server_name example.com;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}

server {
    listen 443 ssl http2;
    server_name example.com;
    
    ssl_certificate /etc/nginx/ssl/example.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/example.com/privkey.pem;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF

# 5. 申请证书
certbot certonly --webroot -w /var/www/certbot -d example.com

# 6. 测试并重载
nginx -t
systemctl reload nginx
```

#### 80/443 端口已被占用

如果 80 或 443 端口被其他服务占用：

**方案 1：使用 Nginx（推荐）**
```bash
# Nginx 可以与其他服务共享端口（通过 server_name 区分）
./install.sh --tls nginx
```

**方案 2：使用非标准端口**
```bash
# 安装时脚本会提示端口占用，可以选择使用非标准端口
# 例如：HTTP 8080, HTTPS 8443
```

**方案 3：停止占用端口的服务**
```bash
# 查看占用端口的服务
netstat -tlnp | grep :80
netstat -tlnp | grep :443

# 停止不需要的服务
systemctl stop apache2
systemctl disable apache2

# 然后安装
./install.sh --tls nginx
```

#### 多站点共存配置示例

假设已有 WordPress 站点在 `blog.example.com`：

```bash
# 1. 安装 V2Ray（使用 Nginx）
./install.sh --tls nginx

# 2. 添加 V2Ray 配置
v2ray add vmess-ws-tls v2ray.example.com

# 3. 手动添加 WordPress 配置（如果脚本没有自动添加）
cat > /etc/nginx/sites-enabled/blog.example.com.conf << 'EOF'
server {
    listen 80;
    server_name blog.example.com;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}

server {
    listen 443 ssl http2;
    server_name blog.example.com;
    
    ssl_certificate /etc/nginx/ssl/blog.example.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/blog.example.com/privkey.pem;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF

# 4. 为 WordPress 申请证书
certbot certonly --webroot -w /var/www/certbot -d blog.example.com

# 5. 测试并重载
nginx -t
systemctl reload nginx
```

**推荐选择：**
- 单 V2Ray 域名 → **Caddy**
- 多域名或已有其他网站 → **Nginx**

### 安装后验证

```bash
# 查看状态
v2ray status

# 预期输出:
# V2Ray v5.x.x: running
# Nginx v1.x.x: running (如果选择 Nginx)
# 或 Caddy v2.x.x: running (如果选择 Caddy)
```

---

## 使用指南

### 命令帮助

```bash
v2ray help
```

### 基本命令

#### 添加配置

```bash
# VMess-WS-TLS (推荐)
v2ray add vmess-ws-tls example.com

# VLESS-gRPC-TLS
v2ray add vless-grpc-tls grpc.example.com

# Trojan-WS-TLS
v2ray add trojan-ws-tls trojan.example.com

# VMess-TCP (无 TLS)
v2ray add vmess-tcp

# Shadowsocks (简单快速)
v2ray add ss
# 或指定端口、密码、加密方式
v2ray add ss 8388 mypassword aes-256-gcm

# Socks (代理协议)
v2ray add socks
# 或指定端口、用户名、密码
v2ray add socks 1080 myuser mypass

# 使用自动参数
v2ray add vmess-ws-tls auto
```

#### 查看配置

```bash
# 列出所有配置
v2ray info

# 查看特定配置
v2ray info VMess-WS-example.com.json

# 查看二维码
v2ray qr VMess-WS-example.com.json

# 查看 URL 链接
v2ray url VMess-WS-example.com.json
```

#### 更改配置

```bash
# 更改端口
v2ray port VMess-WS-example.com.json 8443

# 更改域名
v2ray host VMess-WS-example.com.com newdomain.com

# 更改路径
v2ray path VMess-WS-example.com.json /newpath

# 更改 UUID
v2ray id VMess-WS-example.com.json $(v2ray uuid)

# 更改密码 (Shadowsocks/Trojan)
v2ray passwd VMess-WS-example.com.json newpassword

# 更改伪装类型
v2ray type VMess-TCP-8080.json http

# 更改伪装网站
v2ray web VMess-WS-example.com.json https://www.google.com

# 更改协议
v2ray new VMess-WS-example.com.json trojan-ws-tls

# 一次性更改多个参数
v2ray full VMess-WS-example.com.json trojan-ws-tls 443 newpassword
```

#### 删除配置

```bash
# 删除单个配置
v2ray del VMess-WS-example.com.json

# 删除多个配置
v2ray ddel config1.json config2.json config3.json
```

### 管理命令

```bash
# 查看状态
v2ray status

# 启动/停止/重启 V2Ray
v2ray start
v2ray stop
v2ray restart

# 启动/停止/重启 Nginx
v2ray restart nginx
v2ray stop nginx

# 启动/停止/重启 Caddy
v2ray restart caddy
v2ray stop caddy

# 测试运行
v2ray test

# 查看日志
v2ray log       # 访问日志
v2ray logerr    # 错误日志

# 设置日志级别
v2ray log warning
v2ray log error
v2ray log none  # 禁用日志
v2ray log del   # 删除日志文件
```

### 更新命令

```bash
# 更新 V2Ray 核心
v2ray update core

# 更新脚本
v2ray update.sh

# 更新 Nginx
v2ray update nginx

# 更新 Caddy
v2ray update caddy

# 更新 geo 数据库
v2ray update dat

# 更新到指定版本
v2ray update core v5.10.0
```

### 其他命令

```bash
# 设置 DNS
v2ray dns 1.1.1.1
v2ray dns 8.8.8.8
v2ray dns https://dns.google/dns-query

# 启用 BBR
v2ray bbr

# 获取可用端口
v2ray get-port

# 获取 UUID
v2ray uuid

# 获取服务器 IP
v2ray ip

# 修复配置
v2ray fix config.json
v2ray fix-all
v2ray fix-nginxfile
v2ray fix-caddyfile

# 卸载
v2ray uninstall

# 重装
v2ray reinstall
```

### 高级命令

```bash
# 生成客户端配置
v2ray client VMess-WS-example.com.json

# 生成完整客户端配置（含路由）
v2ray client VMess-WS-example.com.json --full

# 测试生成配置（不保存）
v2ray gen vmess-ws-tls example.com

# 禁止自动 TLS
v2ray no-auto-tls add vmess-ws-tls example.com

# 使用 V2Ray 原生命令
v2ray bin version
v2ray api stats
v2ray tls --cert /path/to/cert
```

---

## Nginx 多站点配置

### 为什么选择 Nginx？

| 场景 | Caddy | Nginx |
|------|-------|-------|
| 单 V2Ray 域名 | ✅ 推荐 | ⚠️ 可用 |
| 多 V2Ray 域名 | ❌ 不推荐 | ✅ 推荐 |
| 与其他网站共存 | ❌ 困难 | ✅ 完美 |
| 共享 80/443 端口 | ❌ 不支持 | ✅ 支持 |
| 配置灵活性 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 性能 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

### 配置结构

```
/etc/nginx/
├── nginx.conf              # 主配置（脚本管理）
├── ssl/                    # SSL 证书目录
│   ├── v2ray.example.com/
│   │   ├── fullchain.pem
│   │   └── privkey.pem
│   ├── blog.example.com/
│   └── api.example.com/
├── v2ray/                  # V2Ray 站点配置
│   ├── v2ray.example.com.conf
│   └── v2ray.example.com.conf.add
└── sites-enabled/          # 其他站点配置（用户管理）
    ├── blog.example.com.conf
    └── api.example.com.conf
```

### 添加 V2Ray 站点

```bash
# 添加第一个 V2Ray 配置
v2ray add vmess-ws-tls v2ray.example.com

# 添加第二个 V2Ray 配置
v2ray add vless-grpc-tls grpc.example.com

# 脚本会自动:
# 1. 生成 V2Ray 配置文件
# 2. 生成 Nginx 配置文件
# 3. 申请 Let's Encrypt 证书
# 4. 重载 Nginx
```

### 添加其他网站

#### 示例：WordPress 博客

1. **创建 Nginx 配置**

```bash
cat > /etc/nginx/sites-enabled/blog.example.com.conf << 'EOF'
# HTTP 服务器
server {
    listen 80;
    server_name blog.example.com;
    
    # ACME 验证
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS 服务器
server {
    listen 443 ssl http2;
    server_name blog.example.com;
    
    # SSL 证书
    ssl_certificate /etc/nginx/ssl/blog.example.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/blog.example.com/privkey.pem;
    
    # SSL 优化
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:50m;
    
    # WordPress 配置
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
```

2. **申请证书**

```bash
certbot certonly --webroot \
    -w /var/www/certbot \
    -d blog.example.com \
    --email admin@blog.example.com \
    --agree-tos \
    --non-interactive
```

3. **测试并重载**

```bash
nginx -t
systemctl reload nginx
```

#### 示例：自定义 API 服务

```bash
cat > /etc/nginx/sites-enabled/api.example.com.conf << 'EOF'
server {
    listen 80;
    server_name api.example.com;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name api.example.com;
    
    ssl_certificate /etc/nginx/ssl/api.example.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/api.example.com/privkey.pem;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
```

### 伪装网站配置

如果要配置伪装网站，修改 `.conf.add` 文件：

```bash
# 编辑伪装配置
vim /etc/nginx/v2ray/v2ray.example.com.conf.add
```

内容示例：

```nginx
# 伪装成 Google
location / {
    proxy_pass https://www.google.com;
    proxy_ssl_server_name on;
    proxy_set_header Host www.google.com;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_buffering off;
}
```

然后重载 Nginx：

```bash
nginx -t && systemctl reload nginx
```

### 证书管理

#### 自动续期

脚本安装时会自动添加定时任务：

```bash
# 查看定时任务
crontab -l | grep certbot

# 输出:
# 0 3 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'
```

#### 手动续期

```bash
# 续期所有证书
certbot renew

# 强制续期特定域名
certbot renew --force-renewal -d example.com

# 测试续期
certbot renew --dry-run
```

#### 查看证书

```bash
# 查看所有证书
certbot certificates

# 查看证书详情
certbot certificates --name example.com
```

---

## 配置参考

### V2Ray 配置文件示例

#### VMess-WS-TLS

```json
{
  "inbounds": [
    {
      "tag": "VMess-WS-example.com.json",
      "port": 10000,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "uuid-here",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "wsSettings": {
          "path": "/path",
          "headers": {
            "Host": "example.com"
          }
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ]
}
```

#### Nginx 配置示例 (VMess-WS-TLS)

```nginx
server {
    listen 80;
    server_name example.com;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name example.com;
    
    ssl_certificate /etc/nginx/ssl/example.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/example.com/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:50m;
    
    location /path {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
    }
}
```

### Caddy 配置示例

```caddy
example.com:443 {
    reverse_proxy /path 127.0.0.1:10000
}
```

### 防火墙配置

#### UFW (Ubuntu/Debian)

```bash
# 允许 SSH
ufw allow 22/tcp

# 允许 HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# 启用防火墙
ufw enable

# 查看状态
ufw status
```

#### Firewalld (CentOS)

```bash
# 允许服务
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https

# 重载
firewall-cmd --reload

# 查看状态
firewall-cmd --list-all
```

---

## 故障排查

### V2Ray 无法启动

```bash
# 查看状态
systemctl status v2ray

# 查看日志
journalctl -u v2ray -f

# 测试配置
v2ray bin run -config /etc/v2ray/config.json -confdir /etc/v2ray/conf

# 检查端口占用
netstat -tlnp | grep :端口号
```

### Nginx 无法启动

```bash
# 测试配置
nginx -t

# 查看错误日志
tail -f /var/log/nginx/error.log

# 查看状态
journalctl -u nginx -f

# 检查端口占用
netstat -tlnp | grep :80
netstat -tlnp | grep :443
```

### 证书申请失败

```bash
# 检查 80 端口是否开放
netstat -tlnp | grep :80

# 检查防火墙
ufw status  # 或 firewall-cmd --list-all

# 检查 DNS 解析
dig example.com
ping example.com

# 手动申请测试
certbot certonly --webroot -w /var/www/certbot -d example.com --dry-run

# 查看详细错误
tail -f /var/log/letsencrypt/letsencrypt.log
```

### WebSocket 连接失败

```bash
# 检查 V2Ray 是否运行
systemctl status v2ray

# 检查 Nginx 配置
cat /etc/nginx/v2ray/example.com.conf

# 测试本地连接
curl -i -H "Upgrade: websocket" -H "Connection: Upgrade" -H "Sec-WebSocket-Key: test" -H "Sec-WebSocket-Version: 13" http://127.0.0.1:端口/path

# 查看 Nginx 访问日志
tail -f /var/log/nginx/access.log
```

### 客户端无法连接

1. **检查服务器状态**
   ```bash
   v2ray status
   ```

2. **检查防火墙**
   ```bash
   ufw status
   ```

3. **检查端口**
   ```bash
   netstat -tlnp | grep v2ray
   ```

4. **检查证书**
   ```bash
   certbot certificates
   ```

5. **重新生成配置**
   ```bash
   v2ray fix 配置名.json
   ```

---

## 常见问题

### Q: 可以同時使用 Caddy 和 Nginx 吗？

**A:** 不建议。两者都会监听 80/443 端口，会产生冲突。选择其中一个即可。

### Q: 如何切换 TLS 方案（Caddy ↔ Nginx）？

**A:** 
```bash
# 卸载当前方案
v2ray uninstall
# 选择卸载 V2Ray + Caddy/Nginx

# 重新安装
./install.sh
# 选择另一个方案
```

### Q: 域名解析后多久能申请证书？

**A:** 通常几分钟内生效。可以使用 `dig example.com` 检查是否已解析到服务器 IP。

### Q: 证书多久续期一次？

**A:** Let's Encrypt 证书有效期 90 天，脚本会在到期前自动续期。

### Q: 如何备份配置？

**A:**
```bash
# 备份 V2Ray 配置
tar czf v2ray-backup.tar.gz /etc/v2ray/

# 备份 Nginx 配置
tar czf nginx-backup.tar.gz /etc/nginx/

# 备份 Caddy 配置
tar czf caddy-backup.tar.gz /etc/caddy/
```

### Q: 如何迁移到另一台服务器？

**A:**
1. 在新服务器安装脚本
2. 恢复备份的配置
3. 重新申请证书（或复制证书）
4. 更新域名 DNS 解析

### Q: 支持 IPv6 吗？

**A:** 支持。脚本会自动检测 IPv6 地址并配置。

### Q: 如何禁用日志？

**A:**
```bash
v2ray log none
```

### Q: 如何查看客户端配置？

**A:**
```bash
v2ray client 配置名.json
```

### Q: 支持 Cloudflare 代理吗？

**A:** 支持。配置 WebSocket 或 gRPC 协议后，在 Cloudflare DNS 设置中将域名代理状态设为 **Proxied (橙色云)** 即可。

```bash
# 添加 VMess-WS-TLS 配置
v2ray add vmess-ws-tls your-domain.com

# 或添加 VLESS-gRPC-TLS 配置
v2ray add vless-grpc-tls grpc.your-domain.com
```

**Cloudflare 配置要点:**

| 设置项 | 推荐配置 | 说明 |
|--------|----------|------|
| **SSL/TLS 模式** | Full 或 Full (Strict) | 必须启用 HTTPS |
| **Proxy 状态** | Proxied (橙色云) | 启用 CDN 代理 |
| **WebSocket 支持** | 自动支持 | 无需额外配置 |
| **gRPC 支持** | 需在 Network 设置中启用 | Cloudflare → Network → gRPC |

**优势:**
- 🛡️ **隐藏真实 IP**: Cloudflare 作为中间层，隐藏 VPS 真实 IP
- 🛡️ **DDoS 防护**: 利用 Cloudflare 的防护能力
- 🚀 **CDN 加速**: 全球节点加速访问
- 🔒 **免费 TLS**: 即使不申请证书，也可用 Cloudflare 的通用证书

**注意事项:**
- ⚠️ 不支持 `VMess-TCP` (无 TLS)、`mKCP`、`QUIC` 等协议
- ⚠️ Cloudflare 只支持特定端口 (80, 443, 8443, 2053, 2083, 2087, 2096 等)

---

## Cloudflare 代理配置

### 概述

本项目完全支持通过 Cloudflare CDN 代理流量。使用 Cloudflare 可以隐藏服务器真实 IP、获得 DDoS 防护、享受全球 CDN 加速。

### 支持的协议

| 协议 | 传输方式 | Cloudflare 支持 | 推荐度 |
|------|----------|----------------|--------|
| VMess | WebSocket + TLS | ✅ 完美支持 | ⭐⭐⭐⭐⭐ |
| VLESS | WebSocket + TLS | ✅ 完美支持 | ⭐⭐⭐⭐⭐ |
| VLESS | gRPC + TLS | ✅ 完美支持 | ⭐⭐⭐⭐ |
| Trojan | WebSocket + TLS | ✅ 完美支持 | ⭐⭐⭐⭐ |
| Trojan | gRPC + TLS | ✅ 完美支持 | ⭐⭐⭐⭐ |
| VMess | H2 + TLS | ✅ 支持 | ⭐⭐⭐ |
| VMess | TCP (无 TLS) | ❌ 不支持 | - |
| VMess | mKCP / QUIC | ❌ 不支持 (UDP) | - |

### 快速配置

#### 步骤 1: 添加 V2Ray 配置

```bash
# 推荐：VMess + WebSocket + TLS
v2ray add vmess-ws-tls your-domain.com

# 或：VLESS + gRPC + TLS
v2ray add vless-grpc-tls grpc.your-domain.com

# 或：Trojan + WebSocket + TLS
v2ray add trojan-ws-tls trojan.your-domain.com
```

#### 步骤 2: 配置 Cloudflare DNS

1. 登录 Cloudflare 控制台
2. 进入 **DNS** 设置页面
3. 添加或编辑 A 记录:
   - **Name**: `your-domain` 或 `@`
   - **Content**: 你的 VPS IP 地址
   - **Proxy status**: **Proxied** (橙色云) ☁️→🌩️

```
类型    名称              内容          代理状态
A       your-domain.com   x.x.x.x       Proxied 🌩️
A       www               x.x.x.x       Proxied 🌩️
```

#### 步骤 3: 配置 Cloudflare SSL/TLS

1. 进入 **SSL/TLS** 设置页面
2. 选择加密模式:
   - **Full**: 基础加密 (推荐)
   - **Full (Strict)**: 严格验证证书 (需要有效证书)

```
SSL/TLS → Overview → Full 或 Full (Strict)
```

#### 步骤 4: (可选) 启用 gRPC 支持

如果使用 gRPC 协议:

1. 进入 **Network** 设置页面
2. 找到 **gRPC** 选项
3. 开启 **Enable gRPC**

```
Network → gRPC → Enable gRPC ✓
```

### Cloudflare 设置详解

#### SSL/TLS 模式对比

| 模式 | 说明 | 推荐场景 |
|------|------|----------|
| **Off** | 不加密 | ❌ 不推荐 |
| **Flexible** | 仅客户端到 Cloudflare 加密 | ⚠️ 安全性较低 |
| **Full** | 全程加密，不验证源站证书 | ✅ 推荐 (自签名证书) |
| **Full (Strict)** | 全程加密，验证源站证书 | ✅✅ 最推荐 (有效证书) |

**建议**: 使用本脚本会自动申请 Let's Encrypt 证书，推荐使用 **Full (Strict)** 模式。

#### 端口限制

Cloudflare 仅代理特定端口，推荐使用:

| 端口 | 用途 |
|------|------|
| 80 | HTTP (自动跳转 HTTPS) |
| 443 | HTTPS (推荐) |
| 8443 | HTTPS 备用 |
| 2053, 2083, 2087, 2096 | HTTPS 备用端口 |

#### WebSocket 配置

Cloudflare 自动支持 WebSocket，无需额外配置:

- **最大消息大小**: 100 MB
- **空闲超时**: 100 秒
- **连接超时**: 30 秒

#### gRPC 配置

启用 gRPC 需要手动开启:

1. **Cloudflare 控制台** → **Network** → **gRPC** → **Enable**
2. 确保使用 **443** 或其他 HTTPS 端口
3. 客户端需支持 gRPC

### 优势与注意事项

#### 优势

✅ **隐藏真实 IP**: Cloudflare 作为反向代理，隐藏 VPS 真实 IP 地址

✅ **DDoS 防护**: 免费享受 Cloudflare 的 DDoS 攻击防护

✅ **CDN 加速**: 全球 200+ 数据中心，加速访问速度

✅ **免费 TLS**: 即使不申请证书，也可使用 Cloudflare 通用证书

✅ **WAF 防护**: Web 应用防火墙，阻挡恶意请求

✅ **Analytics**: 详细的流量分析和统计

#### 注意事项

⚠️ **协议限制**: Cloudflare 仅代理 HTTP/HTTPS/gRPC 流量
- 不支持: TCP (无 TLS)、mKCP、QUIC 等基于 UDP 的协议

⚠️ **端口限制**: 只能使用 Cloudflare 支持的端口列表

⚠️ **WebSocket 超时**: 空闲连接 100 秒后可能断开，建议客户端配置重连

⚠️ **带宽限制**: 
- 免费版：每月 100,000 次请求
- Pro 版：每月 1,000,000 次请求
- Business 版：无限

⚠️ **规则限制**: 遵守 Cloudflare 服务条款，不得用于违法用途

### 客户端配置示例

#### VMess + WebSocket + TLS

```json
{
  "v": "2",
  "ps": "VMess-WS-TLS",
  "add": "your-domain.com",
  "port": "443",
  "id": "uuid-here",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "your-domain.com",
  "path": "/your-path",
  "tls": "tls",
  "sni": "your-domain.com"
}
```

#### VLESS + gRPC + TLS

```json
{
  "v": "0",
  "ps": "VLESS-gRPC-TLS",
  "add": "grpc.your-domain.com",
  "port": "443",
  "id": "uuid-here",
  "flow": "",
  "net": "grpc",
  "type": "none",
  "host": "",
  "path": "path",
  "tls": "tls",
  "sni": "grpc.your-domain.com",
  "alpn": "h2"
}
```

### 故障排查

#### Cloudflare 显示 521/522 错误

**原因**: Cloudflare 无法连接到源站

**解决**:
```bash
# 检查 V2Ray 状态
v2ray status

# 检查 Nginx/Caddy 状态
v2ray status nginx
# 或
v2ray status caddy

# 检查防火墙
ufw status

# 检查端口监听
netstat -tlnp | grep :443
```

#### WebSocket 连接失败

**检查 Nginx 配置**:
```bash
cat /etc/nginx/v2ray/your-domain.com.conf
```

确保包含 WebSocket 升级头:
```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

#### gRPC 无法连接

1. 确认 Cloudflare 已启用 gRPC 支持
2. 检查客户端是否支持 gRPC
3. 确保使用 443 端口

### 性能优化建议

1. **启用 Cloudflare 缓存**: 对静态资源启用缓存
2. **使用 Argo Smart Routing**: 优化路由 (付费功能)
3. **开启 HTTP/2**: Cloudflare 默认支持
4. **开启 HTTP/3**: 在 **Network** 设置中启用
5. **使用 Polish**: 自动优化图片 (付费功能)

---

## 附录

### 相关链接

- **GitHub**: https://github.com/WangYan-Good/v2ray
- **文档**: https://wangyan-good.github.io/v2ray/
- **Telegram**: https://t.me/tg233boy
- **V2Ray 官方**: https://www.v2fly.org
- **Nginx 官方**: https://nginx.org
- **Certbot 官方**: https://certbot.eff.org

### 许可证

GPL-3.0 License

### 致谢

感谢所有贡献者和使用者！

---

*最后更新：2026 年*
