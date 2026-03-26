# V2Ray VPS 架构自动部署功能实现文档

## 概述

本实现为 V2Ray VPS 架构添加了自动部署功能，包括：
- Caddy/Nginx 配置自动生成
- 配置变更检测机制
- 交互式错误处理
- 完善的清理功能

## 文件结构

### 新增/修改的文件

```
/home/node/.openclaw/v2ray/
├── src/
│   └── core.sh                    # 修改 - 集成 auto_deploy 函数
├── scripts/
│   └── v2ray-vps-auto-deploy.sh    # 新建 - 主部署脚本
└── tests/
    ├── unit/
    │   ├── run_auto_deploy_tests.sh  # 新建 - 单元测试
    │   └── auto_deploy_test.bats     # 新建 - BATS 单元测试
    └── integration/
        └── test_auto_deploy.sh       # 新建 - 集成测试
```

## 实现细节

### 1. auto_deploy_vps_architecture() 函数 (core.sh)

**位置**: `/home/node/.openclaw/v2ray/src/core.sh` (第 71 行开始)

**功能**:
- 验证 V2Ray 配置文件
- 提取配置信息（端口、协议、网络类型、域名等）
- 检测配置变更（SHA256 哈希比较）
- 调用 `deploy_web_proxy()` 部署 Web 代理
- 更新状态文件

**参数**:
- `$1` - 配置文件路径
- `$2` - Web 服务器类型 (caddy 或 nginx)
- `$3` - 是否强制部署 (可选，默认 false)

**调用点**:
- `create()` 函数 (第 787 行)
- `change()` 函数 (多个位置)

### 2. cleanup_vps_architecture() 函数 (core.sh)

**位置**: `/home/node/.openclaw/v2ray/src/core.sh` (第 195 行开始)

**功能**:
- 提取配置信息
- 清理 Web 代理配置
- 更新状态文件

**参数**:
- `$1` - 配置文件路径
- `$2` - Web 服务器类型 (caddy 或 nginx)

**调用点**:
- `del()` 函数 (第 1227 行)

### 3. v2ray-vps-auto-deploy.sh 脚本

**位置**: `/home/node/.openclaw/v2ray/scripts/v2ray-vps-auto-deploy.sh`

**主要函数**:
- `check_dependencies()` - 检查依赖 (jq, v2ray, caddy/nginx)
- `validate_v2ray_config()` - 验证 V2Ray 配置
- `extract_v2ray_config()` - 提取配置信息
- `detect_config_changes()` - 检测配置变更
- `generate_caddy_config()` - 生成 Caddy 配置
- `generate_nginx_config()` - 生成 Nginx 配置
- `deploy_web_proxy()` - 部署 Web 代理
- `cleanup_web_proxy()` - 清理 Web 代理

**命令行接口**:
```bash
# 部署
./scripts/v2ray-vps-auto-deploy.sh deploy \
  --config /etc/v2ray/config.json \
  --web-server caddy \
  --domain example.com

# 清理
./scripts/v2ray-vps-auto-deploy.sh cleanup \
  --config /etc/v2ray/config.json \
  --web-server caddy

# 验证
./scripts/v2ray-vps-auto-deploy.sh validate \
  --config /etc/v2ray/config.json

# 显示状态
./scripts/v2ray-vps-auto-deploy.sh status
```

**选项**:
- `--config FILE` - V2Ray 配置文件路径
- `--web-server SERVER` - Web 服务器类型 (caddy 或 nginx)
- `--domain DOMAIN` - 域名
- `--port PORT` - 端口
- `--uuid UUID` - UUID (VMess/VLESS)
- `--password PASSWORD` - 密码 (Trojan/Shadowsocks)
- `--ssl-cert PATH` - SSL 证书路径 (Nginx)
- `--ssl-key PATH` - SSL 密钥路径 (Nginx)
- `--force` - 强制部署 (跳过变更检测)
- `--silent` - 静默模式
- `--log-level LEVEL` - 日志级别 (debug, info, warn, error)

## 核心功能

### 1. 配置抽取

从 V2Ray 配置文件中提取：
- inbound 端口
- 协议类型 (vmess, vless, trojan, shadowsocks)
- 传输方式 (ws, h2, grpc, tcp)
- 安全类型 (tls, reality)
- 域名 (Host)
- UUID/密码

### 2. 变更检测

使用 SHA256 哈希值比较配置文件：
```json
{
  "config_hash": "abc123...",
  "last_updated": "2026-03-26T18:17:29+00:00"
}
```

### 3. 代理配置生成

#### Caddy 配置
```caddy
example.com:443 {
    reverse_proxy 127.0.0.1:8443
    tls admin@example.com {
        protocols tls1.2 tls1.3
    }
    header {
        -Server
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
    }
}
```

#### Nginx 配置
```nginx
server {
    listen 443 ssl http2;
    server_name example.com;
    
    ssl_certificate /etc/ssl/certs/dummy.crt;
    ssl_certificate_key /etc/ssl/private/dummy.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    location / {
        proxy_pass http://127.0.0.1:8443;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## 集成点

### create() 函数
```bash
# 只有 TLS 协议（WS/H2/gRPC）需要配置反向代理
# 使用新的 V2Ray VPS 架构自动部署功能
[[ $HOST && ! $IS_NO_AUTO_TLS && $IS_USE_TLS ]] && {
    # 确定 Web 服务器类型
    local web_server=""
    if [[ $IS_CADDY ]]; then
        web_server="caddy"
    elif [[ $IS_NGINX ]]; then
        web_server="nginx"
    fi
    
    # 自动部署 VPS 架构
    if [[ -n "$web_server" ]]; then
        auto_deploy_vps_architecture "$IS_JSON_FILE" "$web_server"
    fi
}
```

### change() 函数
在所有 `add $NET` 调用后添加自动部署：
```bash
add $NET $IS_NEW_HOST
[[ $IS_JSON_FILE && -f "$IS_JSON_FILE" && -n "$web_server" ]] && \
    auto_deploy_vps_architecture "$IS_JSON_FILE" "$web_server" "true"
```

### del() 函数
```bash
# 使用新的 V2Ray VPS 架构清理功能
local web_server=""
if [[ $IS_CADDY ]]; then
    web_server="caddy"
elif [[ $IS_NGINX ]]; then
    web_server="nginx"
fi

if [[ -n "$web_server" && -n "$IS_CONFIG_FILE" && -n "$HOST" ]]; then
    # 清理 VPS 架构
    cleanup_vps_architecture "$IS_CONF_DIR/$IS_CONFIG_FILE" "$web_server"
fi
```

## 测试

### 单元测试
```bash
cd /home/node/.openclaw/v2ray/tests/unit
./run_auto_deploy_tests.sh
```

### 集成测试
```bash
cd /home/node/.openclaw/v2ray
./tests/integration/test_auto_deploy.sh
```

### 测试覆盖率
- ✅ auto_deploy_vps_architecture() 函数存在
- ✅ cleanup_vps_architecture() 函数存在
- ✅ core.sh 集成 auto_deploy_vps_architecture()
- ✅ create() 集成 auto_deploy_vps_architecture()
- ✅ change() 集成 auto_deploy_vps_architecture()
- ✅ del() 集成 cleanup_vps_architecture()
- ✅ 脚本语法验证
- ✅ 配置文件验证
- ✅ 配置信息提取
- ✅ 状态管理
- ✅ 部署脚本帮助信息
- ✅ 错误处理
- ✅ 配置变更检测

## 依赖项

### 必需依赖
- jq >= 1.6 (JSON 处理)
- bash >= 4.0

### 可选依赖
- v2ray (验证配置语法)
- caddy (Web 服务器)
- nginx (Web 服务器)

## 状态管理

状态文件路径: `/var/lib/v2ray-webproxy/state.json`

格式:
```json
{
  "config_hash": "sha256_hash_here",
  "last_updated": "2026-03-26T18:17:29+00:00"
}
```

## 安全性

1. **输入验证**: 所有配置参数都经过验证
2. **错误处理**: 非交互模式下自动失败，不等待用户输入
3. **配置验证**: 使用 V2Ray 内置验证功能
4. **日志记录**: 详细的日志记录便于审计

## 注意事项

1. **首次部署**: 确保 Web 服务器已安装并配置
2. **证书管理**: Caddy 会自动申请证书，Nginx 需要手动管理
3. **端口冲突**: 部署后检查端口是否被占用
4. **服务重载**: 修改配置后需要重载 Web 服务器
5. **权限**: 部署脚本可能需要 root 权限

## 故障排除

### 1. jq 未安装
```bash
sudo apt install jq  # Ubuntu/Debian
sudo yum install jq  # CentOS/RHEL
brew install jq      # macOS
```

### 2. V2Ray 配置无效
```bash
v2ray -test -config /etc/v2ray/config.json
```

### 3. Web 服务器重载失败
```bash
# Caddy
sudo systemctl reload caddy

# Nginx
sudo systemctl reload nginx
```

## 维护

### 查看状态
```bash
./scripts/v2ray-vps-auto-deploy.sh status
```

### 强制重新部署
```bash
./scripts/v2ray-vps-auto-deploy.sh deploy \
  --config /etc/v2ray/config.json \
  --web-server caddy \
  --force
```

### 清理配置
```bash
./scripts/v2ray-vps-auto-deploy.sh cleanup \
  --config /etc/v2ray/config.json \
  --web-server caddy
```

## 更新日志

### v2ray-vps-auto-deploy.sh 1.0.0 (2026-03-26)
- 首次 release
- 实现完整的自动部署功能
- 添加变更检测机制
- 添加清理功能
- 添加单元测试和集成测试

## 参考文献

- V2Ray 官方文档: https://www.v2ray.com/
- Caddy 官方文档: https://caddyserver.com/docs
- Nginx 官方文档: https://nginx.org/en/docs/
