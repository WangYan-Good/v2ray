# 故障排除指南更新 - Nginx + Certbot 一键配置

## 新增故障排查条目

### 1. 安装相关问题

#### 问题 1.1: 安装时无法选择 Nginx 选项

**症状**: 安装脚本没有显示 Nginx 选项

**原因**: 脚本版本过旧

**解决方案**:
```bash
# 更新到最新版本
v2ray update.sh

# 或重新安装
./install.sh
```

#### 问题 1.2: 环境变量 V2RAY_WEB_SERVER 未生效

**症状**: 设置 `V2RAY_WEB_SERVER=nginx` 但仍然安装 Caddy

**原因**: 环境变量格式不正确

**解决方案**:
```bash
# 正确的格式（小写）
V2RAY_WEB_SERVER=nginx ./install.sh

# 错误的格式
V2RAY_WEB_SERVER=Nginx ./install.sh  # 大写不会生效
```

### 2. 证书申请问题

#### 问题 2.1: 证书申请失败 - DNS 解析错误

**症状**: 
```
Failed to authorize certificate for example.com
Could not bind to the port.
```

**原因**: 域名 DNS 未正确解析或端口 80 被阻止

**解决方案**:
```bash
# 1. 检查 DNS 解析
dig example.com
# 或
nslookup example.com

# 2. 检查 80 端口
netstat -tuln | grep :80

# 3. 检查防火墙
ufw status
iptables -L

# 4. 临时关闭防火墙测试
ufw disable
# 申请证书后再开启
ufw enable
```

#### 问题 2.2: 证书申请失败 - Nginx 配置验证失败

**症状**: 
```
nginx: configuration file test is failed
nginx: [emerg] unknown directive "xxx"
```

**原因**: Nginx 配置文件有语法错误

**解决方案**:
```bash
# 查看具体的错误信息
nginx -t 2>&1

# 检查配置文件
cat /etc/nginx/v2ray/VMess-WS-example.com.conf

# 查看 Nginx 主配置
cat /etc/nginx/nginx.conf
```

#### 问题 2.3: 证书即将过期但未自动续期

**症状**: 证书过期，网站无法访问

**原因**: Certbot 定时任务未运行

**解决方案**:
```bash
# 1. 手动续期
certbot renew

# 2. 检查定时任务
crontab -l
systemctl list-timers | grep certbot

# 3. 手动添加续期任务
echo "0 3 * * * /usr/bin/certbot renew --quiet" | crontab -
```

### 3. Nginx 配置问题

#### 问题 3.1: Nginx 配置未生成

**症状**: 添加配置后，Nginx 配置文件不存在

**原因**: Nginx 未安装或未选择 Nginx

**解决方案**:
```bash
# 1. 检查 Nginx 是否安装
which nginx
nginx -v

# 2. 检查配置文件目录
ls -la /etc/nginx/v2ray/

# 3. 重新添加配置
v2ray del VMess-WS-example.com
v2ray add vmess-ws-tls example.com
```

#### 问题 3.2: Nginx 重载失败

**症状**: 
```
Nginx 重载失败
nginx: signal process failed
```

**原因**: Nginx 未运行或配置错误

**解决方案**:
```bash
# 1. 检查 Nginx 状态
systemctl status nginx

# 2. 测试配置
nginx -t

# 3. 启动 Nginx
systemctl start nginx

# 4. 重载 Nginx
systemctl reload nginx
```

#### 问题 3.3: 配置文件重叠

**症状**: 多个配置使用相同的端口或域名

**原因**: 手动修改配置文件导致冲突

**解决方案**:
```bash
# 查看所有配置
ls -la /etc/nginx/v2ray/

# 删除重复的配置
v2ray del <duplicate_config>

# 重新添加
v2ray add vmess-ws-tls newdomain.com
```

### 4. 协议支持问题

#### 问题 4.1: TCP 协议不能使用 Nginx

**症状**: 尝试添加 TCP 协议时警告 Nginx 不支持

**原因**: TCP 协议不需要 Nginx，直接使用 V2Ray

**说明**: 
- TCP/mKCP/QUIC 协议：不使用 Nginx，直接运行
- WS/H2/gRPC 协议：使用 Nginx 进行 WebSocket/H2/gRPC 转发

**解决方案**:
```bash
# TCP 协议不需要 Nginx
v2ray add vmess-tcp 8080

# WS 协议需要 Nginx
v2ray add vmess-ws-tls example.com
```

#### 问题 4.2: gRPC 配置失败

**症状**: gRPC 配置生成失败

**原因**: Nginx 未正确配置 gRPC 支持

**解决方案**:
```bash
# 检查 Nginx 版本（需要 1.13.10+）
nginx -v

# 手动添加 gRPC 配置
cat > /etc/nginx/v2ray/VLESS-GRPC-grpc.example.com.conf <<EOF
server {
    listen 443 ssl http2;
    server_name grpc.example.com;

    ssl_certificate /etc/nginx/ssl/grpc.example.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/grpc.example.com/privkey.pem;

    location / {
        grpc_pass grpc://127.0.0.1:12345;
    }
}
EOF

nginx -t
systemctl reload nginx
```

### 5. 性能问题

#### 问题 5.1: Nginx 内存占用过高

**症状**: VPS 内存使用率过高

**解决方案**:
```bash
# 调整 Nginx worker 数量
vim /etc/nginx/nginx.conf

# 示例配置
worker_processes auto;
worker_connections 1024;

# 重启 Nginx
systemctl restart nginx
```

#### 问题 5.2: 延迟过高

**症状**: 连接延迟明显高于预期

**原因**: Nginx 配置未优化

**解决方案**:
```bash
# 启用 Gzip 压缩（可选）
vim /etc/nginx/nginx.conf

# 启用 SSL 会话缓存
ssl_session_cache shared:SSL:50m;
ssl_session_timeout 1d;

# 重载 Nginx
systemctl reload nginx
```

### 6. 安全问题

#### 问题 6.1: SSL/TLS 配置不安全

**症状**: SSL Labs 测试评分较低

**解决方案**:
```bash
# 更新 SSL 配置
cat > /etc/nginx/ssl.conf <<EOF
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:50m;
ssl_session_timeout 1d;
EOF

# 包含配置
cat > /etc/nginx/v2ray/VMess-WS-example.com.conf <<EOF
# ... 其他配置
include /etc/nginx/ssl.conf;
EOF

nginx -t
systemctl reload nginx
```

#### 问题 6.2: 证书权限问题

**症状**: Certbot 无法更新证书

**解决方案**:
```bash
# 检查证书目录权限
ls -la /etc/letsencrypt/

# 修复权限
chown -R root:root /etc/letsencrypt/
chmod -R 755 /etc/letsencrypt/

# 重新申请证书
certbot certonly --webroot -w /var/www/certbot -d example.com
```

## 错误代码说明

| 错误代码 | 描述 | 建议操作 |
|----------|------|----------|
| `ERR_NGINX_NOT_INSTALLED` | Nginx 未安装 | 运行 `v2ray install-nginx` |
| `ERR_CERT_FAILED` | 证书申请失败 | 检查 DNS 和端口 80 |
| `ERR_CERT_EXPIRED` | 证书已过期 | 运行 `certbot renew` |
| `ERR_NGINX_CONFIG_FAILED` | Nginx 配置测试失败 | 运行 `nginx -t` 查看详细信息 |
| `ERR_NGINX_RELOAD_FAILED` | Nginx 重载失败 | 检查 Nginx 是否运行 |
| `ERR_PORT_OCCUPIED` | 端口被占用 | 使用 `lsof -i :80` 检查 |
| `ERR_DNS_FAILED` | DNS 解析失败 | 检查域名解析设置 |
| `ERR_PROTOCOL_NOT_SUPPORT` | 协议不支持 | 检查协议类型（仅支持 WS/H2/gRPC） |

## 快速诊断命令

```bash
# 1. 检查 Nginx 状态
systemctl status nginx --no-pager

# 2. 测试 Nginx 配置
nginx -t

# 3. 查看 Nginx 错误日志
tail -f /var/log/nginx/error.log

# 4. 查看证书信息
openssl x509 -noout -dates -in /etc/nginx/ssl/example.com/fullchain.pem

# 5. 检查端口占用
lsof -i :80 -i :443

# 6. 查看 Certbot 状态
certbot certificates

# 7. 查看 V2Ray 配置
v2ray info

# 8. 测试 V2Ray
v2ray test
```

## 联系支持

如果遇到无法解决的问题：

1. 检查日志文件
2. 运行诊断命令
3. 提供错误信息和系统信息
4. 查看 GitHub Issues
