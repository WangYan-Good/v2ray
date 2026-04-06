# T2: XHTTP 协议支持测试用例

> 任务: 添加 XHTTP 协议支持 (VLESS-XHTTP-TLS, Trojan-XHTTP-TLS)
> 创建时间: 2026-04-07
> 状态: 🟡 待执行
> 负责人: -

---

## 背景

XHTTP 是 Xray-core 的新传输层协议，支持多路复用和更好的网络适应性。当前 `core.sh` 中已有基础 JSON 生成逻辑 (第 1664-1668 行)，但未加入协议列表，Nginx 配置也被错误归类到 H2 分支。

---

## 测试用例总览

| 用例 ID | 测试类型 | 测试内容 | 优先级 |
|---------|----------|----------|--------|
| TC-01 | 功能测试 | 添加 VLESS-XHTTP-TLS 配置 (默认参数) | 🔴 P0 |
| TC-02 | 功能测试 | 添加 VLESS-XHTTP-TLS 配置 (指定域名/端口/路径) | 🔴 P0 |
| TC-03 | 功能测试 | 查看 XHTTP 配置信息 | 🔴 P0 |
| TC-04 | 功能测试 | 添加 Trojan-XHTTP-TLS 配置 | 🔴 P0 |
| TC-05 | 功能测试 | 生成 XHTTP 分享链接 | 🔴 P0 |
| TC-06 | 功能测试 | 更改 XHTTP 配置参数 (端口/路径/域名) | 🟡 P1 |
| TC-07 | 功能测试 | 删除 XHTTP 配置 | 🔴 P0 |
| TC-08 | 集成测试 | XHTTP JSON 格式验证 | 🔴 P0 |
| TC-09 | 集成测试 | Nginx 配置生成验证 (证书/反向代理) | 🔴 P0 |
| TC-10 | 集成测试 | Xray 服务启动验证 | 🔴 P0 |
| E2E-01 | 端到端测试 | 客户端通过 XHTTP 代理访问互联网 | 🔴 P0 |
| E2E-02 | 端到端测试 | 出口 IP 验证 (应为服务器 IP) | 🔴 P0 |
| E2E-03 | 端到端测试 | HTTPS 网站访问测试 | 🟡 P1 |
| E2E-04 | 端到端测试 | HTTP 网站访问测试 | 🟡 P1 |
| E2E-05 | 端到端测试 | 与 REALITY 协议共存测试 | 🟡 P1 |

---

## TC-01: 添加 VLESS-XHTTP-TLS 配置 (默认参数)

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | Xray 已安装, Nginx 运行中, 有可用域名 |
| **测试目标** | 验证 `xray add vless-xhttp-tls` 能使用默认参数成功创建配置 |

### 测试步骤

```bash
xray add vless-xhttp-tls test-xhttp.example.com
```

### 预期结果

```
✅ 命令退出码 = 0
✅ 生成配置文件: /etc/xray/conf/VLESS-XHTTP-TLS-test-xhttp.example.com.json
✅ Nginx 配置生成: /etc/nginx/xray/test-xhttp.example.com.conf
✅ SSL 证书申请成功
✅ 输出包含 UUID, path, port
```

---

## TC-02: 添加 VLESS-XHTTP-TLS 配置 (指定参数)

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 同上 |
| **测试目标** | 验证指定参数创建配置 |

### 测试步骤

```bash
xray add vless-xhttp-tls test-xhttp2.example.com 443 $(xray uuid) /custom-xhttp-path
```

### 预期结果

```
✅ 端口 = 443
✅ UUID = 指定值
✅ path = /custom-xhttp-path
✅ JSON 中 xhttpSettings.path = "/custom-xhttp-path"
```

---

## TC-03: 查看 XHTTP 配置信息

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 已存在 XHTTP 配置 |
| **测试目标** | 验证 info 命令正确显示 XHTTP 配置 |

### 预期结果

```
✅ 输出包含:
   - 协议 (protocol): vless 或 trojan
   - 地址 (address): <服务器IP>
   - 端口 (port): 443
   - 用户ID/密码
   - 传输协议 (network): xhttp
   - 伪装域名 (host): <domain>
   - 路径 (path): <path>
   - 传输层安全 (TLS): tls
```

---

## TC-04: 添加 Trojan-XHTTP-TLS 配置

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 同上 |
| **测试目标** | 验证 Trojan 协议的 XHTTP 传输 |

### 预期结果

```
✅ 配置文件生成
✅ protocol = trojan
✅ network = xhttp
✅ security = tls
✅ 密码字段正确
```

---

## TC-05: 生成 XHTTP 分享链接

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 已存在 XHTTP 配置 |
| **测试目标** | 验证分享链接格式 |

### 预期结果

```
✅ VLESS 格式:
   vless://uuid@host:port?encryption=none&security=tls&type=xhttp&host=domain&path=/path#tag

✅ Trojan 格式:
   trojan://password@host:port?security=tls&type=xhttp&host=domain&path=/path#tag
```

---

## TC-06: 更改 XHTTP 配置参数

| 字段 | 内容 |
|------|------|
| **优先级** | 🟡 P1 |
| **前置条件** | 已存在 XHTTP 配置 |
| **测试目标** | 验证端口/路径/域名更改 |

### 预期结果

```
✅ 端口更改后 Nginx 配置同步更新
✅ 路径更改后 JSON 和 Nginx location 同步
✅ 域名更改后 SSL 证书和 Nginx server_name 更新
```

---

## TC-07: 删除 XHTTP 配置

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 已存在 XHTTP 配置 |
| **测试目标** | 验证配置和关联文件清理 |

### 预期结果

```
✅ 配置文件删除
✅ Nginx 配置删除
✅ 重启后服务正常 (无错误)
```

---

## TC-08: XHTTP JSON 格式验证

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 已存在 XHTTP 配置 |
| **测试目标** | 验证 JSON 结构符合 Xray XHTTP 规范 |

### 验证命令

```bash
CONFIG=/etc/xray/conf/VLESS-XHTTP-TLS-*.json
jq '.inbounds[0]' $CONFIG
```

### 预期结果

```json
{
  "tag": "VLESS-XHTTP-TLS-domain.json",
  "port": 443,
  "listen": "127.0.0.1",
  "protocol": "vless",
  "settings": {
    "clients": [{"id": "..."}],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "xhttp",
    "security": "tls",
    "xhttpSettings": {
      "path": "/uuid",
      "host": "domain.com",
      "mode": "auto"
    }
  },
  "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
}
```

---

## TC-09: Nginx 配置生成验证

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 已存在 XHTTP 配置 |
| **测试目标** | 验证 Nginx 配置正确处理 XHTTP 流量 |

### 验证命令

```bash
NGINX_CONF=/etc/nginx/xray/domain.com.conf
cat $NGINX_CONF
```

### 预期结果

```nginx
server {
    listen 443 ssl http2;
    server_name domain.com;
    
    ssl_certificate ...;
    ssl_certificate_key ...;
    
    location /path {
        proxy_pass http://127.0.0.1:port;
        # WebSocket upgrade headers
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## TC-10: Xray 服务启动验证

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 已存在 XHTTP 配置 |
| **测试目标** | 验证服务能加载 XHTTP 配置并正常启动 |

### 预期结果

```
✅ xray status 显示 running
✅ XHTTP 端口正常监听
✅ 无错误日志
```

---

## E2E-01: 客户端通过 XHTTP 代理访问互联网

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 服务端 XHTTP 配置完成，客户端 Xray 安装 |
| **测试目标** | 验证 XHTTP 协议端到端连通性 |

### 预期结果

```
✅ 客户端能建立 TLS 连接
✅ 代理隧道建立成功
✅ 能访问互联网
```

---

## E2E-02: 出口 IP 验证

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | E2E-01 通过 |
| **测试目标** | 验证流量经服务器中转 |

### 预期结果

```
✅ 出口 IP = 服务器 IP (107.174.218.158)
```

---

## E2E-03 ~ E2E-05: 网站访问和协议共存

| 字段 | 内容 |
|------|------|
| **优先级** | 🟡 P1 |
| **前置条件** | E2E-02 通过 |

### 预期结果

```
✅ Google/YouTube 可访问
✅ HTTP 网站可访问
✅ REALITY 和 XHTTP 配置共存且互不干扰
```

---

## 测试结果汇总

| 用例 ID | 测试结果 | 执行时间 | 执行者 | 备注 |
|---------|----------|----------|--------|------|
| TC-01 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-02 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-03 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-04 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-05 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-06 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-07 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-08 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-09 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-10 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| E2E-01 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| E2E-02 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| E2E-03 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| E2E-04 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| E2E-05 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |

---

*文档创建: 2026-04-07 | 状态: 待执行*
