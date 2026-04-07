# Xray 脚本完整文档

> 一个支持多站点共存的 Xray 一键安装和管理脚本

> **本项目 Fork 自**: [233boy/v2ray](https://github.com/233boy/v2ray)
> **主要改进**: 添加 Nginx + Certbot 多站点共存支持，支持 REALITY / XHTTP 等新特性

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
10. [附录](#附录)

---

## 项目概述

### 简介

这是一个 **Xray 一键安装脚本和管理脚本**，支持两种 TLS 方案：
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
/etc/xray/
├── bin/                    # Xray 核心二进制
│   ├── xray
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
│   └── xray.sh            # 主入口
├── conf/                   # Xray 配置文件
│   ├── VMess-WS-8080.json
│   └── VLESS-gRPC-443.json
└── config.json             # 主配置文件

/etc/nginx/                 # Nginx 方案目录
├── nginx.conf              # 主配置
├── ssl/                    # SSL 证书
│   └── 域名/
├── xray/                   # Xray 站点配置
│   └── 域名.conf
└── sites-enabled/          # 其他站点配置

/etc/caddy/                 # Caddy 方案目录
├── Caddyfile               # 主配置
└── xray/                   # Xray 站点配置
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
用户命令 (xray xxx)
    │
    ▼
xray.sh (入口)
    │
    ▼
init.sh (初始化)
    │
    ├─► 检测 Xray 状态
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

**在线一键安装（推荐）**

```bash
# v1.1.0 一键安装（使用 curl）
bash <(curl -Ls https://raw.githubusercontent.com/WangYan-Good/xray/v1.1.0/install.sh)

# 备用地址（使用 jsDelivr CDN 加速）
bash <(curl -Ls https://cdn.jsdelivr.net/gh/WangYan-Good/xray@v1.1.0/install.sh)

# 或使用 wget
bash <(wget -qO- https://raw.githubusercontent.com/WangYan-Good/xray/v1.1.0/install.sh)

# 指定 TLS 方案
bash <(curl -Ls https://raw.githubusercontent.com/WangYan-Good/xray/v1.1.0/install.sh) --tls nginx
bash <(curl -Ls https://raw.githubusercontent.com/WangYan-Good/xray/v1.1.0/install.sh) --tls caddy
```

**手动下载安装**

```bash
# 下载安装脚本
wget -O install.sh https://github.com/WangYan-Good/xray/releases/latest/download/install.sh
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
xray update.sh
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
cp -rf /path/to/xray/src/* /etc/xray/sh/src/

# 2. 复制主脚本
cp /path/to/xray/xray.sh /etc/xray/sh/

# 3. 验证版本
xray version
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
  - 开始下载 Xray 核心
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
开始卸载 Xray 和相关组件...
[步骤 1/6] 删除 Xray 文件...
  - 已删除 /etc/xray
  - 已删除 /var/log/xray
  - 已删除 /usr/local/bin/xray
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
# 自定义 Xray 版本
./install.sh -v v5.10.0

# 使用代理下载
./install.sh -p http://127.0.0.1:2333

# 本地安装（使用当前目录脚本）
./install.sh -l

# 自定义核心文件
./install.sh -f /root/xray-linux-64.zip

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
- ✅ 在现有配置中添加 `include` 导入 Xray 配置

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

如果主机已安装 Nginx，但想改用 Caddy 部署 Xray：

**方案 1：停止 Nginx 并安装 Caddy（推荐）**

```bash
# 1. 停止 Nginx
systemctl stop nginx
systemctl disable nginx

# 2. 备份 Nginx 配置（可选）
cp -rf /etc/nginx /etc/nginx.bak

# 3. 安装 Caddy + Xray
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

# 3. 安装 Caddy + Xray
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

如果主机已安装 Caddy，但想改用 Nginx 部署 Xray：

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

# 3. 安装 Nginx + Xray
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
# 1. 安装 Xray（使用 Nginx）
./install.sh --tls nginx

# 2. 添加 Xray 配置
xray add vmess-ws-tls xray.example.com

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
- 单 Xray 域名 → **Caddy**
- 多域名或已有其他网站 → **Nginx**

### 安装后验证

```bash
# 查看状态
xray status

# 预期输出:
# Xray v5.x.x: running
# Nginx v1.x.x: running (如果选择 Nginx)
# 或 Caddy v2.x.x: running (如果选择 Caddy)
```

---

## 使用指南

### 命令帮助

```bash
xray help
```

### 基本命令

#### 添加配置

```bash
# VMess-WS-TLS (推荐)
xray add vmess-ws-tls example.com

# VLESS-gRPC-TLS
xray add vless-grpc-tls grpc.example.com

# Trojan-WS-TLS
xray add trojan-ws-tls trojan.example.com

# VMess-TCP (无 TLS)
xray add vmess-tcp

# Shadowsocks (简单快速)
xray add ss
# 或指定端口、密码、加密方式
xray add ss 8388 mypassword aes-256-gcm

# Socks (代理协议)
xray add socks
# 或指定端口、用户名、密码
xray add socks 1080 myuser mypass

# 使用自动参数
xray add vmess-ws-tls auto
```

#### 查看配置

```bash
# 列出所有配置
xray info

# 查看特定配置
xray info VMess-WS-example.com.json

# 查看二维码
xray qr VMess-WS-example.com.json

# 查看 URL 链接
xray url VMess-WS-example.com.json
```

#### 更改配置

```bash
# 更改端口
xray port VMess-WS-example.com.json 8443

# 更改域名
xray host VMess-WS-example.com.com newdomain.com

# 更改路径
xray path VMess-WS-example.com.json /newpath

# 更改 UUID
xray id VMess-WS-example.com.json $(xray uuid)

# 更改密码 (Shadowsocks/Trojan)
xray passwd VMess-WS-example.com.json newpassword

# 更改伪装类型
xray type VMess-TCP-8080.json http

# 更改伪装网站
xray web VMess-WS-example.com.json https://www.google.com

# 更改协议
xray new VMess-WS-example.com.json trojan-ws-tls

# 一次性更改多个参数
xray full VMess-WS-example.com.json trojan-ws-tls 443 newpassword
```

#### 删除配置

```bash
# 删除单个配置
xray del VMess-WS-example.com.json

# 删除多个配置
xray ddel config1.json config2.json config3.json
```

### 管理命令

```bash
# 查看状态
xray status

# 启动/停止/重启 Xray
xray start
xray stop
xray restart

# 启动/停止/重启 Nginx
xray restart nginx
xray stop nginx

# 启动/停止/重启 Caddy
xray restart caddy
xray stop caddy

# 测试运行
xray test

# 查看日志
xray log       # 访问日志
xray logerr    # 错误日志

# 设置日志级别
xray log warning
xray log error
xray log none  # 禁用日志
xray log del   # 删除日志文件
```

### 更新命令

```bash
# 更新 Xray 核心
xray update core

# 更新脚本
xray update.sh

# 更新 Nginx
xray update nginx

# 更新 Caddy
xray update caddy

# 更新 geo 数据库
xray update dat

# 更新到指定版本
xray update core v5.10.0
```

### 其他命令

```bash
# 设置 DNS
xray dns 1.1.1.1
xray dns 8.8.8.8
xray dns https://dns.google/dns-query

# 启用 BBR
xray bbr

# 获取可用端口
xray get-port

# 获取 UUID
xray uuid

# 获取服务器 IP
xray ip

# 修复配置
xray fix config.json
xray fix-all
xray fix-nginxfile
xray fix-caddyfile

# 卸载
xray uninstall

# 重装
xray reinstall
```

### 高级命令

```bash
# 生成客户端配置
xray client VMess-WS-example.com.json

# 生成完整客户端配置（含路由）
xray client VMess-WS-example.com.json --full

# 测试生成配置（不保存）
xray gen vmess-ws-tls example.com

# 禁止自动 TLS
xray no-auto-tls add vmess-ws-tls example.com

# 使用 Xray 原生命令
xray bin version
xray api stats
xray tls --cert /path/to/cert
```

---

## Nginx 多站点配置

### 为什么选择 Nginx？

| 场景 | Caddy | Nginx |
|------|-------|-------|
| 单 Xray 域名 | ✅ 推荐 | ⚠️ 可用 |
| 多 Xray 域名 | ❌ 不推荐 | ✅ 推荐 |
| 与其他网站共存 | ❌ 困难 | ✅ 完美 |
| 共享 80/443 端口 | ❌ 不支持 | ✅ 支持 |
| 配置灵活性 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 性能 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

### 配置结构

```
/etc/nginx/
├── nginx.conf              # 主配置（脚本管理）
├── ssl/                    # SSL 证书目录
│   ├── xray.example.com/
│   │   ├── fullchain.pem
│   │   └── privkey.pem
│   ├── blog.example.com/
│   └── api.example.com/
├── xray/                  # Xray 站点配置
│   ├── xray.example.com.conf
│   └── xray.example.com.conf.add
└── sites-enabled/          # 其他站点配置（用户管理）
    ├── blog.example.com.conf
    └── api.example.com.conf
```

### 添加 Xray 站点

```bash
# 添加第一个 Xray 配置
xray add vmess-ws-tls xray.example.com

# 添加第二个 Xray 配置
xray add vless-grpc-tls grpc.example.com

# 脚本会自动:
# 1. 生成 Xray 配置文件
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
vim /etc/nginx/xray/xray.example.com.conf.add
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

### Xray 配置文件示例

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

### Xray 无法启动

```bash
# 查看状态
systemctl status xray

# 查看日志
journalctl -u xray -f

# 测试配置
xray bin run -config /etc/xray/config.json -confdir /etc/xray/conf

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
# 检查 Xray 是否运行
systemctl status xray

# 检查 Nginx 配置
cat /etc/nginx/xray/example.com.conf

# 测试本地连接
curl -i -H "Upgrade: websocket" -H "Connection: Upgrade" -H "Sec-WebSocket-Key: test" -H "Sec-WebSocket-Version: 13" http://127.0.0.1:端口/path

# 查看 Nginx 访问日志
tail -f /var/log/nginx/access.log
```

### 客户端无法连接

1. **检查服务器状态**
   ```bash
   xray status
   ```

2. **检查防火墙**
   ```bash
   ufw status
   ```

3. **检查端口**
   ```bash
   netstat -tlnp | grep xray
   ```

4. **检查证书**
   ```bash
   certbot certificates
   ```

5. **重新生成配置**
   ```bash
   xray fix 配置名.json
   ```

---

## 常见问题

### Q: 可以同時使用 Caddy 和 Nginx 吗？

**A:** 不建议。两者都会监听 80/443 端口，会产生冲突。选择其中一个即可。

### Q: 如何切换 TLS 方案（Caddy ↔ Nginx）？

**A:** 
```bash
# 卸载当前方案
xray uninstall
# 选择卸载 Xray + Caddy/Nginx

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
# 备份 Xray 配置
tar czf xray-backup.tar.gz /etc/xray/

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
xray log none
```

### Q: 如何查看客户端配置？

**A:**
```bash
xray client 配置名.json
```

### Q: 支持 Cloudflare 代理吗？

**A:** 支持。配置流程分为两个阶段：

**阶段 1 - 申请证书（必须关闭代理）:**
```bash
# 1. Cloudflare DNS 设置：DNS only (灰色云) ☁️
# 2. 添加配置
xray add vmess-ws-tls your-domain.com
# 3. 脚本自动申请 Let's Encrypt 证书
```

**阶段 2 - 正常使用（开启代理享受 CDN）:**
```bash
# 1. Cloudflare DNS 设置：Proxied (橙色云) 🌩️
# 2. SSL/TLS 模式：Full 或 Full (Strict)
# 3. 正常使用
```

> ⚠️ **重要**: 申请证书时必须关闭 Cloudflare 代理，因为 Let's Encrypt 需要直接访问你的服务器验证域名所有权。

**Cloudflare 配置要点:**

| 设置项 | 推荐配置 | 说明 |
|--------|----------|------|
| **SSL/TLS 模式** | Full 或 Full (Strict) | 必须启用 HTTPS |
| **Proxy 状态（申请证书时）** | DNS only (灰色云) | 让 Let's Encrypt 验证域名 |
| **Proxy 状态（正常使用）** | Proxied (橙色云) | 启用 CDN 代理 |
| **WebSocket 支持** | 自动支持 | 无需额外配置 |
| **gRPC 支持** | 需在 Network 设置中启用 | Cloudflare → Network → gRPC |

**优势:**
- 🛡️ **隐藏真实 IP**: Cloudflare 作为中间层，隐藏 VPS 真实 IP
- 🛡️ **DDoS 防护**: 利用 Cloudflare 的防护能力
- 🚀 **CDN 加速**: 全球 200+ 数据中心，加速访问速度
- 🔒 **免费 TLS**: 使用 Let's Encrypt 或 Cloudflare 通用证书

**注意事项:**
- ⚠️ 不支持 `VMess-TCP` (无 TLS)、`mKCP`、`QUIC` 等协议
- ⚠️ Cloudflare 只支持特定端口 (80, 443, 8443, 2053, 2083, 2087, 2096 等)
- ⚠️ WebSocket 空闲超时 100 秒，建议客户端配置自动重连

### Q: 域名解析到 Cloudflare IP，脚本提示错误怎么办？

**A:** 这是正常现象。脚本需要验证域名解析到你的 VPS 真实 IP。

**解决方法:**
1. **临时关闭 Cloudflare 代理**（灰色云）
2. **等待 DNS 生效**（1-5 分钟）
3. **运行脚本添加配置**
4. **配置完成后，重新开启代理**（橙色云）

```bash
# 验证 DNS 是否生效
dig your-domain.com

# 应该返回你的 VPS IP，而不是 Cloudflare IP
```

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

> ⚠️ **重要提示**: 配置流程分为两个阶段
> - **阶段 1（申请证书）**: Cloudflare 必须设为 **DNS only (灰色云)** ☁️
> - **阶段 2（正常使用）**: Cloudflare 可以设为 **Proxied (橙色云)** 🌩️

#### 步骤 1: 添加 Xray 配置

```bash
# 推荐：VMess + WebSocket + TLS
xray add vmess-ws-tls your-domain.com

# 或：VLESS + gRPC + TLS
xray add vless-grpc-tls grpc.your-domain.com

# 或：Trojan + WebSocket + TLS
xray add trojan-ws-tls trojan.your-domain.com
```

#### 步骤 2: 配置 Cloudflare DNS（阶段 1 - 申请证书）

> ⚠️ **申请 Let's Encrypt 证书时，必须关闭 Cloudflare 代理！**
> 
> 原因：Let's Encrypt 需要直接访问你的服务器验证域名所有权。

1. 登录 Cloudflare 控制台
2. 进入 **DNS** 设置页面
3. 添加或编辑 A 记录:
   - **Name**: `your-domain` 或 `@`
   - **Content**: 你的 VPS IP 地址
   - **Proxy status**: **DNS only** (灰色云) ☁️

```
类型    名称              内容          代理状态
A       your-domain.com   x.x.x.x       DNS only ☁️
```

4. **等待 DNS 生效**（通常 1-5 分钟）
5. **验证解析**: `dig your-domain.com` 应返回你的 VPS IP

#### 步骤 3: 运行脚本添加配置

```bash
xray add vmess-ws-tls your-domain.com
```

脚本会自动：
- ✅ 验证域名解析
- ✅ 申请 Let's Encrypt 证书
- ✅ 配置 Nginx/Caddy
- ✅ 生成 Xray 配置

#### 步骤 4: 开启 Cloudflare 代理（阶段 2 - 正常使用）

> 配置完成后，可以开启 Cloudflare 代理享受 CDN 和防护

1. 回到 Cloudflare **DNS** 设置页面
2. 将代理状态改为 **Proxied** (橙色云) 🌩️

```
类型    名称              内容          代理状态
A       your-domain.com   x.x.x.x       Proxied 🌩️
```

3. **SSL/TLS** 设置:
   - 进入 **SSL/TLS** → **Overview**
   - 选择 **Full** 或 **Full (Strict)**

```
SSL/TLS → Overview → Full (Strict) ✓
```

#### 步骤 5: (可选) 启用 gRPC 支持

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

#### 证书申请失败：Connection refused

**错误信息**:
```
Detail: 72.11.140.248: Fetching http://your-domain.com/.well-known/acme-challenge/...
        Connection refused
```

**原因**: Nginx 未运行，80 端口无法访问

**解决**（脚本已自动修复）:
```bash
# 脚本会自动执行以下操作：
# 1. 检测 Nginx 状态
# 2. 自动启动 Nginx
# 3. 测试 Nginx 配置
# 4. 重新申请证书

# 如果仍然失败，手动执行：
systemctl start nginx
certbot certonly --webroot -w /var/www/certbot -d your-domain.com
```

**脚本自动处理流程**:
```
1. 检测 Nginx 是否运行 → 未运行
2. 自动启动 Nginx → systemctl start nginx
3. 测试 Nginx 配置 → nginx -t
4. 申请证书 → certbot certonly --webroot
5. 成功 → 重载 Nginx
6. 失败 → 给出详细提示
```

**常见失败原因**:
- ❌ 域名未解析到 VPS IP（Cloudflare 未关闭代理）
- ❌ 防火墙未开放 80 端口
- ❌ Nginx 配置错误
- ❌ 端口被其他程序占用

**检查命令**:
```bash
# 验证 DNS 解析
dig your-domain.com +short

# 检查防火墙
ufw status

# 检查 80 端口
netstat -tlnp | grep :80

# 测试 HTTP 访问
curl -I http://your-domain.com/.well-known/acme-challenge/test

# 查看 Certbot 日志
tail -20 /var/log/letsencrypt/letsencrypt.log
```

#### Cloudflare 显示 521/522 错误

**原因**: Cloudflare 无法连接到源站

**解决**:
```bash
# 检查 Xray 状态
xray status

# 检查 Nginx/Caddy 状态
xray status nginx
# 或
xray status caddy

# 检查防火墙
ufw status

# 检查端口监听
netstat -tlnp | grep :443
```

#### WebSocket 连接失败

**检查 Nginx 配置**:
```bash
cat /etc/nginx/xray/your-domain.com.conf
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

- **GitHub**: https://github.com/WangYan-Good/xray
- **文档**: https://wangyan-good.github.io/xray/
- **Xray 官方**: https://www.v2fly.org
- **Nginx 官方**: https://nginx.org
- **Certbot 官方**: https://certbot.eff.org

### 许可证

GPL-3.0 License

### 致谢

感谢所有贡献者和使用者！

---

## 开发者指南

### 如何发布新版本

**1. 打包脚本代码**

将 `xray.sh` 和 `src/` 目录打包成 `code.zip`（`install.sh` 运行时会自动下载并解压此文件）：

```bash
cd /path/to/xray
zip -r code.zip xray.sh src/
```

**2. 创建 Release 并上传资产**

使用 `gh` 命令行工具创建 Release 并上传 `install.sh` 和 `code.zip`：

```bash
# 创建 Release（同时创建 git tag）
gh release create <version> \
  --title "📦 <version> - xray <title>" \
  --notes "# ✨ 主要功能\n\n- # 🐛 Bug 修复\n\n- # 🔧 技术改进" \
  --target develop \
  install.sh \
  code.zip
```

**3. 推送 tag**

```bash
git push origin develop --tags
```

### 发布后验证

发布完成后，以下链接会自动指向最新版本：

| 资源 | URL |
|------|-----|
| Release 页面 | https://github.com/WangYan-Good/xray/releases/latest |
| 安装脚本 | https://github.com/WangYan-Good/xray/releases/latest/download/install.sh |
| 脚本代码 | https://github.com/WangYan-Good/xray/releases/latest/download/code.zip |

这意味着**手动安装命令永远无需修改**，用户每次执行都会自动获取最新版本：

```bash
# 用户永远只需执行此命令即可安装最新版
wget -O install.sh https://github.com/WangYan-Good/xray/releases/latest/download/install.sh
chmod +x install.sh && ./install.sh
```

### 安装流程说明

```
用户下载 install.sh
       │
       ▼
install.sh 从 releases/latest/download/code.zip 下载脚本代码
       │
       ▼
解压到 /etc/xray/sh/
       │
       ▼
安装完成
```

---

*最后更新：2026 年*
