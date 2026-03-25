# V2Ray Phase 9 - 架构修复方案

**创建日期**: 2026-03-25 06:55 UTC  
**作者**: Architect Subagent  
**状态**: 待审批  

---

## 执行摘要

Phase 7-8 修复了 29 处 Shell 引用错误，但 VPS 真实环境验证时发现 jq 解析失败。根本原因是 `core.sh` 生成的不是有效 JSON，而是"类似 JSON 的字符串"。

**核心问题**: 所有 JSON 相关变量使用字符串拼接方式生成，键名没有引号包裹，导致 jq 无法正确解析。

**修复策略**: 全面重构 JSON 生成逻辑，使用 jq 原生构建 JSON，而非字符串拼接。

---

## 1. 缺陷分析

### 1.1 问题分类

| 缺陷类型 | 数量 | 严重程度 | 描述 |
|----------|------|----------|------|
| 伪 JSON 字符串 | 14 处 | 🔴 严重 | 变量生成的是无效 JSON 字符串 |
| jq quoting 错误 | 5 处 | 🔴 严重 | inline jq 命令 quoting 方式错误 |
| 测试覆盖不足 | 2 处 | 🟡 中等 | 测试未验证 JSON 有效性 |

### 1.2 受影响变量详细清单

#### 1.2.1 IS_SERVER_ID_JSON (5 处)

| 行号 | 协议 | 当前代码 | 问题 |
|------|------|----------|------|
| 1417 | VMess (动态端口) | `IS_SERVER_ID_JSON="settings:{clients:[{id:\"$UUID\"}],detour:{to:\"$IS_CONFIG_NAME-link.json\"}}"` | 键名无引号 |
| 1419 | VMess | `IS_SERVER_ID_JSON="settings:{clients:[{id:\"$UUID\"}]}"` | 键名无引号 |
| 1425 | VLESS | `IS_SERVER_ID_JSON="settings:{clients:[{id:\"$UUID\"}],decryption:\"none\"}"` | 键名无引号 |
| 1428 | VLESS-Reality | `IS_SERVER_ID_JSON="settings:{clients:[{id:\"$UUID\",flow:\"xtls-rprx-vision\"}],decryption:\"none\"}"` | 键名无引号 |
| 1435 | Trojan | `IS_SERVER_ID_JSON="settings:{clients:[{password:\"$TROJAN_PASSWORD\"}]}"` | 键名无引号 |

#### 1.2.2 IS_CLIENT_ID_JSON (5 处)

| 行号 | 协议 | 当前代码 | 问题 |
|------|------|----------|------|
| 1421 | VMess | `IS_CLIENT_ID_JSON="settings:{vnext:[{address:\"$IS_ADDR\",port:\"$PORT\",users:[{id:\"$UUID\"}]}]}"` | 键名无引号 |
| 1426 | VLESS | `IS_CLIENT_ID_JSON="settings:{vnext:[{address:\"$IS_ADDR\",port:\"$PORT\",users:[{id:\"$UUID\",encryption:\"none\"}]}]}"` | 键名无引号 |
| 1429 | VLESS-Reality | `IS_CLIENT_ID_JSON="settings:{vnext:[{address:\"$IS_ADDR\",port:\"$PORT\",users:[{id:\"$UUID\",encryption:\"none\",flow:\"xtls-rprx-vision\"}]}]}"` | 键名无引号 |
| 1436 | Trojan | `IS_CLIENT_ID_JSON="settings:{servers:[{address:\"$IS_ADDR\",port:\"$PORT\",password:\"$TROJAN_PASSWORD\"}]}"` | 键名无引号 |
| 1447 | Shadowsocks | `IS_CLIENT_ID_JSON="settings:{servers:[{address:\"$IS_ADDR\",port:\"$PORT\",method:\"$SS_METHOD\",password:\"$SS_PASSWORD\",}]}"` | 键名无引号，尾部多余逗号 |

#### 1.2.3 JSON_STR (7 处)

| 行号 | 协议/用途 | 当前代码 | 问题 |
|------|-----------|----------|------|
| 1448 | Shadowsocks (服务端) | `JSON_STR="settings:{method:\"$SS_METHOD\",password:\"$SS_PASSWORD\",network:\"tcp,udp\"}"` | 键名无引号 |
| 1453 | Dokodemo-door | `JSON_STR="settings:{port:\"$DOOR_PORT\",address:\"$DOOR_ADDR\",network:\"tcp,udp\"}"` | 键名无引号 |
| 1458 | HTTP | `JSON_STR="settings:{\"timeout\": 233}"` | 部分正确，但整体仍无效 |
| 1465 | Socks | `JSON_STR="settings:{auth:\"password\",accounts:[{user:\"$IS_SOCKS_USER\",pass:\"$IS_SOCKS_PASS\"}],udp:true,ip:\"0.0.0.0\"}"` | 键名无引号 |
| 1477 | TCP 传输层 | `JSON_STR="\"$IS_SERVER_ID_JSON\",\"$IS_STREAM\""` | 组合错误字符串 |
| 1484-1519 | 其他传输层 | 同上 | 同上 |

#### 1.2.4 IS_STREAM (7 处)

| 行号 | 传输类型 | 问题 |
|------|----------|------|
| 1476 | TCP | `streamSettings:{network:\"tcp\",...}` 键名无引号 |
| 1483 | KCP | 同上 |
| 1489 | QUIC | 同上 |
| 1495 | WS | 同上 |
| 1502 | gRPC | 同上 |
| 1508 | H2 | 同上 |
| 1515/1517 | Reality | 同上 |

#### 1.2.5 其他相关变量

| 变量 | 行号 | 问题 |
|------|------|------|
| IS_SNIFFING | 392 | `sniffing:{enabled:true,destOverride:["http","tls"]}` 键名无引号 |
| IS_LISTEN | 389 | 可能存在问题，需检查 |

### 1.3 根本原因分析

**设计缺陷** (而非实现错误):

1. **错误的设计理念**: 试图通过字符串拼接生成 JSON，而非使用专门的 JSON 构建工具
2. **对 JSON 规范理解不足**: JSON 要求所有键名必须用双引号包裹
3. **Shell quoting 复杂性**: 在 Shell 中正确转义 JSON 字符串极其复杂且易错
4. **测试方法缺陷**: 使用 heredoc 测试，未模拟真实 inline jq 命令场景

---

## 2. 修复方案

### 2.1 设计原则

1. **使用 jq 原生构建 JSON**: 利用 jq 的 `-n` 和 `--arg`/`--argjson` 参数
2. **零字符串拼接**: 完全避免手动拼接 JSON 字符串
3. **函数化封装**: 为每种协议创建独立的 JSON 生成函数
4. **保持可读性**: 代码结构清晰，易于维护和扩展

### 2.2 核心修复模式

#### 2.2.1 当前错误模式

```bash
# ❌ 错误：字符串拼接
IS_SERVER_ID_JSON="settings:{clients:[{password:\"$TROJAN_PASSWORD\"}]}"
IS_NEW_JSON=$(jq '{inbounds:[{tag:'\"$IS_CONFIG_NAME\"',port:'"$PORT"','"$IS_LISTEN"',protocol:'\"$IS_PROTOCOL\"','"$JSON_STR"'}]}' <<<{})
```

#### 2.2.2 推荐修复模式

```bash
# ✅ 正确：jq 原生构建
generate_settings_json() {
    local protocol="$1"
    shift
    case "$protocol" in
        trojan)
            jq -n --arg pwd "$1" '{
                clients: [{ password: $pwd }]
            }'
            ;;
        vmess)
            jq -n --arg id "$1" '{
                clients: [{ id: $id }]
            }'
            ;;
        # ... 其他协议
    esac
}

generate_stream_json() {
    local network="$1"
    shift
    case "$network" in
        tcp)
            jq -n --arg type "$1" '{
                network: "tcp",
                tcpSettings: { header: { type: $type } }
            }'
            ;;
        # ... 其他传输类型
    esac
}

# 构建完整配置
IS_NEW_JSON=$(jq -n \
    --arg tag "$IS_CONFIG_NAME" \
    --argjson port "$PORT" \
    --arg protocol "$IS_PROTOCOL" \
    --argjson settings "$(generate_settings_json trojan "$TROJAN_PASSWORD")" \
    --argjson streamSettings "$(generate_stream_json tcp "$HEADER_TYPE")" \
    '{
        inbounds: [{
            tag: $tag,
            port: $port,
            listen: "127.0.0.1",
            protocol: $protocol,
            settings: $settings,
            streamSettings: $streamSettings
        }]
    }')
```

### 2.3 具体代码修改方案

#### 2.3.1 新增辅助函数 (添加到 core.sh 开头附近)

```bash
# ============================================================================
# JSON 生成辅助函数 - Phase 9 修复
# ============================================================================

# 生成协议 settings JSON
generate_protocol_settings() {
    local protocol="$1"
    shift
    
    case "$protocol" in
        vmess)
            local uuid="$1"
            local detour="$2"
            if [[ $detour ]]; then
                jq -n --arg id "$uuid" --arg detour "$detour" '{
                    clients: [{ id: $id }],
                    detour: { to: $detour }
                }'
            else
                jq -n --arg id "$uuid" '{
                    clients: [{ id: $id }]
                }'
            fi
            ;;
        vless)
            local uuid="$1"
            local flow="$2"
            if [[ $flow ]]; then
                jq -n --arg id "$uuid" --arg flow "$flow" '{
                    clients: [{ id: $id, flow: $flow }],
                    decryption: "none"
                }'
            else
                jq -n --arg id "$uuid" '{
                    clients: [{ id: $id }],
                    decryption: "none"
                }'
            fi
            ;;
        trojan)
            local password="$1"
            jq -n --arg pwd "$password" '{
                clients: [{ password: $pwd }]
            }'
            ;;
        shadowsocks)
            local method="$1"
            local password="$2"
            jq -n --arg method "$method" --arg pwd "$password" '{
                method: $method,
                password: $pwd,
                network: "tcp,udp"
            }'
            ;;
        socks)
            local user="$1"
            local pass="$2"
            jq -n --arg user "$user" --arg pass "$pass" '{
                auth: "password",
                accounts: [{ user: $user, pass: $pass }],
                udp: true,
                ip: "0.0.0.0"
            }'
            ;;
        http)
            jq -n '{
                timeout: 233
            }'
            ;;
        dokodemo-door)
            local addr="$1"
            local port="$2"
            jq -n --arg addr "$addr" --argjson port "$port" '{
                address: $addr,
                port: $port,
                network: "tcp,udp"
            }'
            ;;
        *)
            echo "{}"
            ;;
    esac
}

# 生成客户端配置 JSON
generate_client_settings() {
    local protocol="$1"
    shift
    
    case "$protocol" in
        vmess|vless)
            local addr="$1"
            local port="$2"
            local uuid="$3"
            local encryption="$4"
            local flow="$5"
            
            if [[ $flow ]]; then
                jq -n --arg addr "$addr" --argjson port "$port" --arg id "$uuid" --arg enc "$encryption" --arg flow "$flow" '{
                    vnext: [{
                        address: $addr,
                        port: $port,
                        users: [{ id: $id, encryption: $enc, flow: $flow }]
                    }]
                }'
            elif [[ $encryption ]]; then
                jq -n --arg addr "$addr" --argjson port "$port" --arg id "$uuid" --arg enc "$encryption" '{
                    vnext: [{
                        address: $addr,
                        port: $port,
                        users: [{ id: $id, encryption: $enc }]
                    }]
                }'
            else
                jq -n --arg addr "$addr" --argjson port "$port" --arg id "$uuid" '{
                    vnext: [{
                        address: $addr,
                        port: $port,
                        users: [{ id: $id }]
                    }]
                }'
            fi
            ;;
        trojan)
            local addr="$1"
            local port="$2"
            local password="$3"
            jq -n --arg addr "$addr" --argjson port "$port" --arg pwd "$password" '{
                servers: [{
                    address: $addr,
                    port: $port,
                    password: $pwd
                }]
            }'
            ;;
        shadowsocks)
            local addr="$1"
            local port="$2"
            local method="$3"
            local password="$4"
            jq -n --arg addr "$addr" --argjson port "$port" --arg method "$method" --arg pwd "$password" '{
                servers: [{
                    address: $addr,
                    port: $port,
                    method: $method,
                    password: $pwd
                }]
            }'
            ;;
        *)
            echo "{}"
            ;;
    esac
}

# 生成传输层 streamSettings JSON
generate_stream_settings() {
    local network="$1"
    shift
    
    case "$network" in
        tcp)
            local header_type="$1"
            jq -n --arg type "$header_type" '{
                network: "tcp",
                tcpSettings: {
                    header: { type: $type }
                }
            }'
            ;;
        kcp)
            local seed="$1"
            local header_type="$2"
            jq -n --arg seed "$seed" --arg type "$header_type" '{
                network: "kcp",
                kcpSettings: {
                    seed: $seed,
                    header: { type: $type }
                }
            }'
            ;;
        quic)
            local header_type="$1"
            jq -n --arg type "$header_type" '{
                network: "quic",
                quicSettings: {
                    header: { type: $type }
                }
            }'
            ;;
        ws)
            local path="$1"
            local host="$2"
            local security="$3"
            jq -n --arg path "$path" --arg host "$host" --arg sec "$security" '{
                network: "ws",
                security: $sec,
                wsSettings: {
                    path: $path,
                    headers: { Host: $host }
                }
            }'
            ;;
        grpc)
            local service_name="$1"
            local host="$2"
            local security="$3"
            jq -n --arg name "$service_name" --arg host "$host" --arg sec "$security" '{
                network: "grpc",
                grpcServiceName: $name,
                security: $sec
            }'
            ;;
        h2)
            local path="$1"
            local host="$2"
            local security="$3"
            jq -n --arg path "$path" --arg host "$host" --arg sec "$security" '{
                network: "h2",
                security: $sec,
                httpSettings: {
                    path: $path,
                    host: [$host]
                }
            }'
            ;;
        reality)
            local dest="$1"
            local server_names="$2"
            local public_key="$3"
            local private_key="$4"
            jq -n --arg dest "$dest" --argjson sn "$server_names" --arg pk "$public_key" --arg sk "$private_key" '{
                network: "tcp",
                security: "reality",
                realitySettings: {
                    dest: $dest,
                    serverNames: $sn,
                    publicKey: $pk,
                    privateKey: $sk,
                    shortIds: [""]
                }
            }'
            ;;
        reality_client)
            local server_name="$1"
            local public_key="$2"
            jq -n --arg sn "$server_name" --arg pk "$public_key" '{
                network: "tcp",
                security: "reality",
                realitySettings: {
                    serverName: $sn,
                    fingerprint: "ios",
                    publicKey: $pk,
                    shortId: "",
                    spiderX: "/"
                }
            }'
            ;;
        *)
            echo '{"network":"tcp"}'
            ;;
    esac
}

# 生成 sniffing 配置 JSON
generate_sniffing() {
    jq -n '{
        enabled: true,
        destOverride: ["http", "tls"]
    }'
}
```

#### 2.3.2 修改 protocol case 块 (core.sh 第 1410-1520 行)

**原代码** (第 1415-1470 行):
```bash
case $IS_LOWER in
vmess*)
    IS_PROTOCOL=vmess
    if [[ $IS_DYNAMIC_PORT ]]; then
        IS_SERVER_ID_JSON="settings:{clients:[{id:\"$UUID\"}],detour:{to:\"$IS_CONFIG_NAME-link.json\"}}"
    else
        IS_SERVER_ID_JSON="settings:{clients:[{id:\"$UUID\"}]}"
    fi
    IS_CLIENT_ID_JSON="settings:{vnext:[{address:\"$IS_ADDR\",port:\"$PORT\",users:[{id:\"$UUID\"}]}]}"
    ;;
# ... 其他协议
```

**修改后**:
```bash
case $IS_LOWER in
vmess*)
    IS_PROTOCOL=vmess
    if [[ $IS_DYNAMIC_PORT ]]; then
        IS_SETTINGS_JSON=$(generate_protocol_settings vmess "$UUID" "$IS_CONFIG_NAME-link.json")
    else
        IS_SETTINGS_JSON=$(generate_protocol_settings vmess "$UUID")
    fi
    IS_CLIENT_SETTINGS_JSON=$(generate_client_settings vmess "$IS_ADDR" "$PORT" "$UUID")
    ;;
vless*)
    IS_PROTOCOL=vless
    if [[ $IS_REALITY ]]; then
        IS_SETTINGS_JSON=$(generate_protocol_settings vless "$UUID" "xtls-rprx-vision")
        IS_CLIENT_SETTINGS_JSON=$(generate_client_settings vless "$IS_ADDR" "$PORT" "$UUID" "none" "xtls-rprx-vision")
    else
        IS_SETTINGS_JSON=$(generate_protocol_settings vless "$UUID")
        IS_CLIENT_SETTINGS_JSON=$(generate_client_settings vless "$IS_ADDR" "$PORT" "$UUID" "none")
    fi
    ;;
trojan*)
    IS_PROTOCOL=trojan
    [[ ! $TROJAN_PASSWORD ]] && TROJAN_PASSWORD=$UUID
    IS_SETTINGS_JSON=$(generate_protocol_settings trojan "$TROJAN_PASSWORD")
    IS_CLIENT_SETTINGS_JSON=$(generate_client_settings trojan "$IS_ADDR" "$PORT" "$TROJAN_PASSWORD")
    IS_TROJAN=1
    ;;
shadowsocks*)
    IS_PROTOCOL=shadowsocks
    NET=ss
    [[ ! $SS_METHOD ]] && SS_METHOD=$IS_RANDOM_SS_METHOD
    [[ ! $SS_PASSWORD ]] && {
        SS_PASSWORD=$UUID
        [[ $(grep 2022 <<<$SS_METHOD) ]] && SS_PASSWORD=$(get ss2022)
    }
    IS_SETTINGS_JSON=$(generate_protocol_settings shadowsocks "$SS_METHOD" "$SS_PASSWORD")
    IS_CLIENT_SETTINGS_JSON=$(generate_client_settings shadowsocks "$IS_ADDR" "$PORT" "$SS_METHOD" "$SS_PASSWORD")
    ;;
dokodemo-door*)
    IS_PROTOCOL=dokodemo-door
    NET=door
    IS_SETTINGS_JSON=$(generate_protocol_settings dokodemo-door "$DOOR_ADDR" "$DOOR_PORT")
    ;;
*http*)
    IS_PROTOCOL=http
    NET=http
    IS_SETTINGS_JSON=$(generate_protocol_settings http)
    ;;
*socks*)
    IS_PROTOCOL=socks
    NET=socks
    [[ ! $IS_SOCKS_USER ]] && IS_SOCKS_USER=admin
    [[ ! $IS_SOCKS_PASS ]] && IS_SOCKS_PASS=$UUID
    IS_SETTINGS_JSON=$(generate_protocol_settings socks "$IS_SOCKS_USER" "$IS_SOCKS_PASS")
    ;;
*)
    err "无法识别协议：$IS_CONFIG_FILE"
    ;;
esac
```

#### 2.3.3 修改传输层 case 块 (core.sh 第 1470-1520 行)

**原代码**:
```bash
case $IS_LOWER in
*tcp*)
    NET=tcp
    [[ ! $HEADER_TYPE ]] && HEADER_TYPE=none
    IS_STREAM="streamSettings:{network:\"tcp\",tcpSettings:{header:{type:\"$HEADER_TYPE\"}}}"
    JSON_STR="\"$IS_SERVER_ID_JSON\",\"$IS_STREAM\""
    ;;
# ... 其他传输类型
```

**修改后**:
```bash
[[ $NET ]] && return # if net exist, dont need more json args

case $IS_LOWER in
*tcp*)
    NET=tcp
    [[ ! $HEADER_TYPE ]] && HEADER_TYPE=none
    IS_STREAM_SETTINGS_JSON=$(generate_stream_settings tcp "$HEADER_TYPE")
    ;;
*kcp* | *mkcp)
    NET=kcp
    [[ ! $HEADER_TYPE ]] && HEADER_TYPE=$IS_RANDOM_HEADER_TYPE
    [[ ! $IS_NO_KCP_SEED && ! $KCP_SEED ]] && KCP_SEED=$UUID
    IS_STREAM_SETTINGS_JSON=$(generate_stream_settings kcp "$KCP_SEED" "$HEADER_TYPE")
    ;;
*quic*)
    NET=quic
    [[ ! $HEADER_TYPE ]] && HEADER_TYPE=$IS_RANDOM_HEADER_TYPE
    IS_STREAM_SETTINGS_JSON=$(generate_stream_settings quic "$HEADER_TYPE")
    ;;
*ws* | *websocket)
    NET=ws
    [[ ! $URL_PATH ]] && URL_PATH="/$UUID"
    IS_STREAM_SETTINGS_JSON=$(generate_stream_settings ws "$URL_PATH" "$HOST" "$IS_TLS")
    ;;
*grpc* | *gun)
    NET=grpc
    [[ ! $URL_PATH ]] && URL_PATH="grpc"
    [[ $URL_PATH == */* ]] && URL_PATH=$(sed 's#/##g' <<<$URL_PATH)
    IS_STREAM_SETTINGS_JSON=$(generate_stream_settings grpc "$URL_PATH" "$HOST" "$IS_TLS")
    ;;
*h2* | *http*)
    NET=h2
    [[ ! $URL_PATH ]] && URL_PATH="/$UUID"
    IS_STREAM_SETTINGS_JSON=$(generate_stream_settings h2 "$URL_PATH" "$HOST" "$IS_TLS")
    ;;
*reality*)
    NET=reality
    [[ ! $IS_SERVERNAME ]] && IS_SERVERNAME=$IS_RANDOM_SERVERNAME
    [[ ! $IS_PRIVATE_KEY ]] && get_pbk
    if [[ $IS_CLIENT ]]; then
        IS_STREAM_SETTINGS_JSON=$(generate_stream_settings reality_client "$IS_SERVERNAME" "$IS_PUBLIC_KEY")
    else
        IS_STREAM_SETTINGS_JSON=$(generate_stream_settings reality "${IS_SERVERNAME}:443" "[\"${IS_SERVERNAME}\",\"\"]" "$IS_PUBLIC_KEY" "$IS_PRIVATE_KEY")
    fi
    ;;
*)
    err "无法识别传输协议：$IS_CONFIG_FILE"
    ;;
esac
```

#### 2.3.4 修改 jq 配置生成命令 (core.sh 第 390-400 行)

**原代码** (第 393 行):
```bash
IS_NEW_JSON=$(jq '{inbounds:[{tag:'\"$IS_CONFIG_NAME\"',port:'"$PORT"','"$IS_LISTEN"',protocol:'\"$IS_PROTOCOL\"','"$JSON_STR"','"$IS_SNIFFING"'}]}' <<<{})
```

**修改后**:
```bash
# 生成 sniffing 配置
IS_SNIFFING_JSON=$(generate_sniffing)

# 构建完整入站配置
IS_NEW_JSON=$(jq -n \
    --arg tag "$IS_CONFIG_NAME" \
    --argjson port "$PORT" \
    --arg listen "$IS_LISTEN_ADDR" \
    --arg protocol "$IS_PROTOCOL" \
    --argjson settings "$IS_SETTINGS_JSON" \
    --argjson streamSettings "$IS_STREAM_SETTINGS_JSON" \
    --argjson sniffing "$IS_SNIFFING_JSON" \
    '{
        inbounds: [{
            tag: $tag,
            port: $port,
            listen: $listen,
            protocol: $protocol,
            settings: $settings,
            streamSettings: $streamSettings,
            sniffing: $sniffing
        }]
    }')
```

#### 2.3.5 修改出站配置生成 (core.sh 第 439 行)

**原代码**:
```bash
IS_NEW_JSON=$(jq '{outbounds:[{tag:'\"$IS_CONFIG_NAME\"',protocol:'\"$IS_PROTOCOL\"','"$IS_CLIENT_ID_JSON"','"$IS_STREAM"'}]}' <<<{})
```

**修改后**:
```bash
IS_NEW_JSON=$(jq -n \
    --arg tag "$IS_CONFIG_NAME" \
    --arg protocol "$IS_PROTOCOL" \
    --argjson settings "$IS_CLIENT_SETTINGS_JSON" \
    --argjson streamSettings "$IS_STREAM_SETTINGS_JSON" \
    '{
        outbounds: [{
            tag: $tag,
            protocol: $protocol,
            settings: $settings,
            streamSettings: $streamSettings
        }]
    }')
```

### 2.4 回退方案

如果修复后发现问题，可以快速回退到 Phase 8 版本:

```bash
# 备份当前版本
cp /home/node/.openclaw/v2ray/src/core.sh /home/node/.openclaw/v2ray/src/core.sh.phase9

# 回退到 Phase 8
git checkout <phase8-commit-hash> -- /home/node/.openclaw/v2ray/src/core.sh

# 或者恢复备份
cp /home/node/.openclaw/v2ray/src/core.sh.phase8 /home/node/.openclaw/v2ray/src/core.sh
```

---

## 3. 影响评估

### 3.1 正面影响

| 影响领域 | 描述 |
|----------|------|
| **正确性** | 生成 100% 有效的 JSON，jq 解析不再失败 |
| **可维护性** | 函数化封装，代码结构清晰，易于理解和修改 |
| **可扩展性** | 新增协议/传输类型只需添加对应的生成函数 |
| **调试友好** | 可以单独测试每个生成函数，定位问题更容易 |
| **安全性** | 避免 Shell 注入风险，jq 自动处理特殊字符转义 |

### 3.2 潜在风险

| 风险 | 严重程度 | 缓解措施 |
|------|----------|----------|
| 性能开销 (多次调用 jq) | 🟡 低 | jq 调用开销很小，配置生成不是高频操作 |
| 函数命名冲突 | 🟡 低 | 使用唯一前缀 `generate_*` |
| 变量名变更导致引用失败 | 🟡 中 | 全面搜索替换，确保所有引用点更新 |
| 旧配置兼容性 | 🟡 中 | 生成的 JSON 格式与 V2Ray 期望一致，不影响已有配置 |

### 3.3 代码变更统计

| 变更类型 | 数量 |
|----------|------|
| 新增函数 | 4 个 (generate_protocol_settings, generate_client_settings, generate_stream_settings, generate_sniffing) |
| 修改变量名 | ~15 处 (IS_*_JSON → IS_*_SETTINGS_JSON) |
| 修改 jq 命令 | 5 处 (配置生成调用点) |
| 删除代码 | ~20 行 (字符串拼接逻辑) |
| 新增代码 | ~200 行 (辅助函数) |

---

## 4. 测试要求

### 4.1 测试类型清单

QA **必须**执行以下测试类型:

#### 4.1.1 本地语法验证

```bash
# Shell 语法检查
bash -n /home/node/.openclaw/v2ray/src/core.sh

# 验证辅助函数定义
source /home/node/.openclaw/v2ray/src/core.sh
declare -f generate_protocol_settings
declare -f generate_client_settings
declare -f generate_stream_settings
declare -f generate_sniffing
```

**验收标准**: 
- ✅ `bash -n` 无语法错误
- ✅ 所有辅助函数正确定义

#### 4.1.2 变量展开验证

```bash
# 测试协议设置生成
UUID="test-uuid-12345"
settings=$(generate_protocol_settings vmess "$UUID")
echo "$settings" | jq .

# 测试客户端设置生成
settings=$(generate_client_settings trojan "example.com" 443 "test-password")
echo "$settings" | jq .

# 测试传输层设置生成
stream=$(generate_stream_settings ws "/path" "example.com" "tls")
echo "$stream" | jq .
```

**验收标准**:
- ✅ 所有函数输出有效 JSON (jq 解析成功)
- ✅ 变量正确展开到 JSON 中
- ✅ JSON 结构符合 V2Ray 配置规范

#### 4.1.3 jq 解析验证 (Inline 命令模拟)

```bash
# 模拟生产环境的 jq 调用
IS_CONFIG_NAME="test-config"
PORT=8443
IS_PROTOCOL="trojan"
IS_SETTINGS_JSON=$(generate_protocol_settings trojan "test-password")
IS_STREAM_SETTINGS_JSON=$(generate_stream_settings h2 "/path" "example.com" "tls")
IS_SNIFFING_JSON=$(generate_sniffing)

IS_NEW_JSON=$(jq -n \
    --arg tag "$IS_CONFIG_NAME" \
    --argjson port "$PORT" \
    --arg protocol "$IS_PROTOCOL" \
    --argjson settings "$IS_SETTINGS_JSON" \
    --argjson streamSettings "$IS_STREAM_SETTINGS_JSON" \
    --argjson sniffing "$IS_SNIFFING_JSON" \
    '{
        inbounds: [{
            tag: $tag,
            port: $port,
            protocol: $protocol,
            settings: $settings,
            streamSettings: $streamSettings,
            sniffing: $sniffing
        }]
    }')

# 验证生成的 JSON
echo "$IS_NEW_JSON" | jq .
```

**验收标准**:
- ✅ jq 命令执行成功 (退出码 0)
- ✅ 生成的 JSON 格式正确
- ✅ 所有字段值正确

#### 4.1.4 VPS 真实环境验证 (**必须!**)

**测试环境要求**:
- 真实 VPS (非本地模拟)
- 已安装 V2Ray 和 jq
- 网络连接正常
- 有可用的域名和 TLS 证书 (测试 TLS 相关协议)

**测试步骤**:

1. **部署修复后的代码到 VPS**
   ```bash
   scp /home/node/.openclaw/v2ray/src/core.sh user@vps:/path/to/v2ray/src/
   ```

2. **测试所有协议的 add 命令**
   ```bash
   # VMess + TCP
   bash core.sh add vmess-tcp --port 10001
   
   # VMess + WS + TLS
   bash core.sh add vmess-ws-tls --port 10002 --host proxy.example.com
   
   # VLESS + TCP
   bash core.sh add vless-tcp --port 10003
   
   # VLESS + Reality
   bash core.sh add vless-reality --port 10004
   
   # Trojan + H2 + TLS
   bash core.sh add trojan-h2-tls --port 10005 --host proxy.example.com
   
   # Shadowsocks + TCP
   bash core.sh add shadowsocks-tcp --port 10006
   
   # Socks + TCP
   bash core.sh add socks-tcp --port 10007
   
   # Dokodemo-door
   bash core.sh add dokodemo-door --port 10008
   ```

3. **验证配置文件内容**
   ```bash
   # 检查生成的配置文件
   cat /etc/v2ray/configs/test-config.json | jq .
   
   # 验证配置能被 V2Ray 接受
   /usr/bin/v2ray -test -config /etc/v2ray/configs/test-config.json
   ```

4. **测试 info 命令**
   ```bash
   bash core.sh info vmess-tcp
   bash core.sh info trojan-h2-tls
   ```

5. **测试 del 命令**
   ```bash
   bash core.sh del vmess-tcp
   ```

6. **验证链接生成**
   ```bash
   # 检查生成的订阅链接格式正确
   bash core.sh info vmess-ws-tls | grep "vmess://"
   bash core.sh info trojan-h2-tls | grep "trojan://"
   ```

**验收标准**:
- ✅ 所有协议的 add 命令成功执行 (退出码 0)
- ✅ 生成的配置文件是有效 JSON
- ✅ V2Ray 配置测试通过 (`-test` 参数)
- ✅ info 命令显示正确信息
- ✅ del 命令成功删除配置
- ✅ 链接格式正确，可导入客户端

#### 4.1.5 配置读写一致性验证

```bash
# 1. 创建配置
bash core.sh add trojan-h2-tls --port 10005 --host proxy.example.com

# 2. 读取配置
config=$(cat /etc/v2ray/configs/trojan-h2-tls.json)

# 3. 验证关键字段
echo "$config" | jq -r '.inbounds[0].protocol'  # 应为 "trojan"
echo "$config" | jq -r '.inbounds[0].port'      # 应为 "10005"
echo "$config" | jq -r '.inbounds[0].settings.clients[0].password'  # 应有值
echo "$config" | jq -r '.inbounds[0].streamSettings.network'  # 应为 "h2"

# 4. 验证 info 命令读取的信息与配置一致
info_output=$(bash core.sh info trojan-h2-tls)
# 对比 info 输出与配置文件内容
```

**验收标准**:
- ✅ 配置文件所有关键字段可正确读取
- ✅ info 命令显示信息与配置文件一致
- ✅ 无数据丢失或变形

### 4.2 测试矩阵

| 协议 | 传输层 | 安全层 | 测试状态 |
|------|--------|--------|----------|
| VMess | TCP | none | ⬜ 待测试 |
| VMess | TCP | TLS | ⬜ 待测试 |
| VMess | WS | none | ⬜ 待测试 |
| VMess | WS | TLS | ⬜ 待测试 |
| VMess | gRPC | TLS | ⬜ 待测试 |
| VMess | H2 | TLS | ⬜ 待测试 |
| VLESS | TCP | none | ⬜ 待测试 |
| VLESS | TCP | Reality | ⬜ 待测试 |
| VLESS | WS | TLS | ⬜ 待测试 |
| VLESS | gRPC | TLS | ⬜ 待测试 |
| Trojan | TCP | TLS | ⬜ 待测试 |
| Trojan | H2 | TLS | ⬜ 待测试 |
| Shadowsocks | TCP | none | ⬜ 待测试 |
| Socks | TCP | none | ⬜ 待测试 |
| Dokodemo-door | TCP | none | ⬜ 待测试 |

**优先级**:
- 🔴 高优先级：Trojan-H2-TLS, VLESS-Reality, VMess-WS-TLS (最常用)
- 🟡 中优先级：VMess-TCP, VLESS-TCP, Shadowsocks-TCP
- 🟢 低优先级：Socks, Dokodemo-door, HTTP

### 4.3 测试脚本模板

创建 `/home/node/.openclaw/v2ray/tests/phase9-json-validation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Phase 9 JSON 生成验证测试脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_SH="$SCRIPT_DIR/../src/core.sh"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass_count=0
fail_count=0

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((pass_count++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((fail_count++))
}

info() {
    echo -e "${YELLOW}INFO${NC}: $1"
}

# 测试 1: Shell 语法检查
test_shell_syntax() {
    info "测试 Shell 语法..."
    if bash -n "$CORE_SH" 2>/dev/null; then
        pass "Shell 语法检查通过"
    else
        fail "Shell 语法检查失败"
        bash -n "$CORE_SH"
        return 1
    fi
}

# 测试 2: 函数定义检查
test_function_definitions() {
    info "测试辅助函数定义..."
    source "$CORE_SH" 2>/dev/null || true
    
    local functions=(
        "generate_protocol_settings"
        "generate_client_settings"
        "generate_stream_settings"
        "generate_sniffing"
    )
    
    for func in "${functions[@]}"; do
        if declare -f "$func" > /dev/null 2>&1; then
            pass "函数 $func 已定义"
        else
            fail "函数 $func 未定义"
        fi
    done
}

# 测试 3: JSON 有效性验证
test_json_validity() {
    info "测试 JSON 生成有效性..."
    source "$CORE_SH" 2>/dev/null || true
    
    # 测试 VMess 协议设置
    local vmess_settings=$(generate_protocol_settings vmess "test-uuid-12345" 2>/dev/null)
    if echo "$vmess_settings" | jq . > /dev/null 2>&1; then
        pass "VMess 设置 JSON 有效"
    else
        fail "VMess 设置 JSON 无效: $vmess_settings"
    fi
    
    # 测试 Trojan 协议设置
    local trojan_settings=$(generate_protocol_settings trojan "test-password" 2>/dev/null)
    if echo "$trojan_settings" | jq . > /dev/null 2>&1; then
        pass "Trojan 设置 JSON 有效"
    else
        fail "Trojan 设置 JSON 无效: $trojan_settings"
    fi
    
    # 测试 WS 传输层设置
    local ws_stream=$(generate_stream_settings ws "/test" "example.com" "tls" 2>/dev/null)
    if echo "$ws_stream" | jq . > /dev/null 2>&1; then
        pass "WS 传输层 JSON 有效"
    else
        fail "WS 传输层 JSON 无效: $ws_stream"
    fi
    
    # 测试 H2 传输层设置
    local h2_stream=$(generate_stream_settings h2 "/test" "example.com" "tls" 2>/dev/null)
    if echo "$h2_stream" | jq . > /dev/null 2>&1; then
        pass "H2 传输层 JSON 有效"
    else
        fail "H2 传输层 JSON 无效: $h2_stream"
    fi
    
    # 测试完整配置生成
    local settings=$(generate_protocol_settings trojan "password123" 2>/dev/null)
    local stream=$(generate_stream_settings h2 "/path" "example.com" "tls" 2>/dev/null)
    local sniffing=$(generate_sniffing 2>/dev/null)
    
    local full_config=$(jq -n \
        --arg tag "test-config" \
        --argjson port 8443 \
        --arg protocol "trojan" \
        --argjson settings "$settings" \
        --argjson streamSettings "$stream" \
        --argjson sniffing "$sniffing" \
        '{
            inbounds: [{
                tag: $tag,
                port: $port,
                protocol: $protocol,
                settings: $settings,
                streamSettings: $streamSettings,
                sniffing: $sniffing
            }]
        }' 2>/dev/null)
    
    if echo "$full_config" | jq . > /dev/null 2>&1; then
        pass "完整配置 JSON 有效"
    else
        fail "完整配置 JSON 无效"
    fi
}

# 测试 4: 变量展开验证
test_variable_expansion() {
    info "测试变量展开..."
    source "$CORE_SH" 2>/dev/null || true
    
    local test_uuid="550e8400-e29b-41d4-a716-446655440000"
    local test_password="secure-password-123"
    local test_host="proxy.example.com"
    
    # 测试 UUID 展开
    local vmess=$(generate_protocol_settings vmess "$test_uuid" 2>/dev/null)
    if [[ "$vmess" == *"$test_uuid"* ]]; then
        pass "UUID 变量正确展开"
    else
        fail "UUID 变量未正确展开"
    fi
    
    # 测试密码展开
    local trojan=$(generate_protocol_settings trojan "$test_password" 2>/dev/null)
    if [[ "$trojan" == *"$test_password"* ]]; then
        pass "密码变量正确展开"
    else
        fail "密码变量未正确展开"
    fi
    
    # 测试主机名展开
    local ws=$(generate_stream_settings ws "/path" "$test_host" "tls" 2>/dev/null)
    if [[ "$ws" == *"$test_host"* ]]; then
        pass "主机名变量正确展开"
    else
        fail "主机名变量未正确展开"
    fi
}

# 运行所有测试
main() {
    echo "========================================="
    echo "Phase 9 JSON 生成验证测试"
    echo "========================================="
    echo
    
    test_shell_syntax
    test_function_definitions
    test_json_validity
    test_variable_expansion
    
    echo
    echo "========================================="
    echo "测试结果汇总"
    echo "========================================="
    echo -e "${GREEN}通过${NC}: $pass_count"
    echo -e "${RED}失败${NC}: $fail_count"
    echo
    
    if [[ $fail_count -eq 0 ]]; then
        echo -e "${GREEN}所有测试通过!${NC}"
        exit 0
    else
        echo -e "${RED}部分测试失败，请检查修复${NC}"
        exit 1
    fi
}

main "$@"
```

---

## 5. 预计工作量

### 5.1 开发阶段

| 任务 | 预计时间 | 负责人 |
|------|----------|--------|
| 编写辅助函数 | 2 小时 | Architect |
| 修改 protocol case 块 | 1 小时 | Architect |
| 修改传输层 case 块 | 1 小时 | Architect |
| 修改 jq 调用点 | 1 小时 | Architect |
| 代码审查 | 1 小时 | Architect + Lead |
| **小计** | **6 小时** | |

### 5.2 测试阶段

| 任务 | 预计时间 | 负责人 |
|------|----------|--------|
| 编写测试脚本 | 2 小时 | QA |
| 本地语法验证 | 0.5 小时 | QA |
| 变量展开验证 | 0.5 小时 | QA |
| jq 解析验证 | 1 小时 | QA |
| VPS 真实环境测试 | 3 小时 | QA |
| 配置读写一致性验证 | 1 小时 | QA |
| 测试报告编写 | 1 小时 | QA |
| **小计** | **9 小时** | |

### 5.3 审核与部署

| 任务 | 预计时间 | 负责人 |
|------|----------|--------|
| QA 测试用例审核 | 1 小时 | Architect |
| 测试报告审核 | 1 小时 | Architect |
| 部署到生产环境 | 0.5 小时 | DevOps |
| 生产验证 | 1 小时 | QA |
| **小计** | **3.5 小时** | |

### 5.4 总计

**总预计工作量**: **18.5 小时** (约 2.5 个工作日)

**时间线**:
- Day 1: 开发 + 代码审查
- Day 2: 测试脚本 + 本地验证
- Day 3: VPS 测试 + 审核部署

---

## 6. 风险评估

### 6.1 技术风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| jq 版本兼容性问题 | 低 | 中 | 测试最低 jq 版本要求 (1.5+) |
| 函数性能开销 | 低 | 低 | 基准测试验证性能影响 |
| 特殊字符转义问题 | 中 | 中 | jq 自动处理，风险较低 |
| 变量作用域问题 | 中 | 中 | 严格使用 local 声明局部变量 |

### 6.2 项目风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| VPS 测试环境不可用 | 低 | 高 | 提前准备备用 VPS |
| 测试覆盖不完整 | 中 | 中 | 使用测试矩阵确保覆盖 |
| 回退时间窗口不足 | 低 | 中 | 选择低峰期部署 |
| 文档更新滞后 | 中 | 低 | 将文档更新纳入完成标准 |

### 6.3 风险缓解策略

1. **渐进式部署**: 先在一台 VPS 上部署测试，验证通过后再推广
2. **快速回退**: 保留 Phase 8 备份，15 分钟内可回退
3. **监控告警**: 部署后监控 VPS 配置生成失败率
4. **用户通知**: 提前通知用户可能的维护窗口

---

## 7. 下一步流程

### 7.1 审批流程

```
[Architect] 提交修复方案
    ↓
[Coordinator] 审批修复方案 ← 当前步骤
    ↓
[QA] 设计测试用例
    ↓
[Architect] 审核测试用例
    ↓
[QA] 执行测试
    ↓
[QA] 提交测试报告
    ↓
[Architect] 审核测试报告
    ↓
[Coordinator] 批准部署
    ↓
[DevOps] 部署到生产环境
```

### 7.2 关键检查点

1. **✅ 修复方案审批** (当前)
   - 方案是否解决根本问题？
   - 代码变更是否合理？
   - 测试要求是否充分？

2. **⬜ 测试用例审核**
   - 是否覆盖所有协议？
   - VPS 测试环境是否就绪？
   - 验收标准是否明确？

3. **⬜ 测试报告审核**
   - 所有测试是否通过？
   - 发现的问题是否修复？
   - 性能影响是否可接受？

4. **⬜ 部署批准**
   - 测试报告是否完整？
   - 回退方案是否就绪？
   - 部署时间窗口是否合适？

### 7.3 成功标准

- ✅ 所有协议的 add/info/del 命令正常工作
- ✅ jq 无语法错误 (本地 + VPS)
- ✅ 配置文件内容正确且可被 V2Ray 接受
- ✅ 链接生成正确，可导入客户端
- ✅ 配置读写一致性验证通过
- ✅ 性能影响 < 5% (配置生成时间)

---

## 8. 附录

### 8.1 参考文档

- [V2Ray 官方配置文档](https://www.v2fly.org/config/)
- [jq 用户手册](https://stedolan.github.io/jq/manual/)
- [Phase 7-8 复盘报告](./V2Ray-jq-Error-PostMortem-Report.md)

### 8.2 相关文件

- `/home/node/.openclaw/v2ray/src/core.sh` - 核心配置文件
- `/home/node/.openclaw/v2ray/tests/phase9-json-validation.sh` - 测试脚本 (待创建)
- `/home/node/.openclaw/workspace-assistant/V2Ray-jq-Error-PostMortem-Report.md` - 复盘报告

### 8.3 术语表

| 术语 | 定义 |
|------|------|
| 伪 JSON | 看起来像 JSON 但不是有效 JSON 格式的字符串 |
| jq | 轻量级 JSON 处理器，用于生成和解析 JSON |
| VPS | Virtual Private Server，虚拟专用服务器 |
| Phase 9 | 本次架构修复项目的代号 |

---

**文档状态**: 待审批  
**最后更新**: 2026-03-25 06:55 UTC  
**版本**: 1.0