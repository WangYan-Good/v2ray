#!/bin/bash
# 集成测试：验证 get info 函数修复

set -e

echo "=== 测试 get info 函数修复 ==="

# 创建测试配置目录
TEST_CONF_DIR="/tmp/v2ray_test_conf_$$"
mkdir -p "$TEST_CONF_DIR"

# 创建 WS+TLS 测试配置
cat > "$TEST_CONF_DIR/ws-tls.json" << 'EOF'
{
  "inbounds": [{
    "protocol": "vmess",
    "port": 443,
    "settings": {
      "clients": [{
        "id": "test-uuid-12345"
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "wsSettings": {
        "path": "/websocket-path",
        "headers": {
          "Host": "ws.example.com"
        }
      }
    }
  }]
}
EOF

# 创建 gRPC+TLS 测试配置
cat > "$TEST_CONF_DIR/grpc-tls.json" << 'EOF'
{
  "inbounds": [{
    "protocol": "vmess",
    "port": 443,
    "settings": {
      "clients": [{
        "id": "test-uuid-67890"
      }]
    },
    "streamSettings": {
      "network": "grpc",
      "security": "tls",
      "grpc_host": "grpc.example.com",
      "grpcSettings": {
        "serviceName": "grpc-service"
      }
    }
  }]
}
EOF

# 创建 H2+TLS 测试配置
cat > "$TEST_CONF_DIR/h2-tls.json" << 'EOF'
{
  "inbounds": [{
    "protocol": "vmess",
    "port": 443,
    "settings": {
      "clients": [{
        "id": "test-uuid-h2test"
      }]
    },
    "streamSettings": {
      "network": "h2",
      "security": "tls",
      "httpSettings": {
        "path": "/h2-path",
        "host": ["h2.example.com"]
      }
    }
  }]
}
EOF

echo "测试配置已创建：$TEST_CONF_DIR"
ls -la "$TEST_CONF_DIR"

# 模拟 get info 函数的关键逻辑
test_config() {
    local config_file="$1"
    local expected_net="$2"
    local expected_path="$3"
    local expected_host="$4"
    
    echo ""
    echo "--- 测试配置：$config_file ---"
    
    local IS_JSON_STR=$(cat "$config_file")
    
    # 使用 jq 查询（使用 printf 避免 echo 解释特殊字符）
    local IS_JSON_DATA_MORE=$(printf '%s\n' "$IS_JSON_STR" | /tmp/jq -r '(.inbounds[0].streamSettings.network//""),(.inbounds[0].streamSettings.security//""),(.inbounds[0].streamSettings.tcpSettings.header.type//""),(.inbounds[0].streamSettings.kcpSettings.seed//""),(.inbounds[0].streamSettings.kcpSettings.header.type//""),(.inbounds[0].streamSettings.quicSettings.header.type//""),(.inbounds[0].streamSettings.wsSettings.path//""),(.inbounds[0].streamSettings.httpSettings.path//""),(.inbounds[0].streamSettings.grpcSettings.serviceName//"")')
    
    local IS_JSON_DATA_HOST=$(printf '%s\n' "$IS_JSON_STR" | /tmp/jq -r '(.inbounds[0].streamSettings.grpc_host//""),(.inbounds[0].streamSettings.wsSettings.headers.Host//""),(.inbounds[0].streamSettings.httpSettings.host[0]//"")')
    
    # 设置变量名数组
    local IS_UP_VAR_SET=(NET IS_SECURITY TCP_TYPE KCP_SEED KCP_TYPE QUIC_TYPE WS_PATH H2_PATH GRPC_SERVICE_NAME GRPC_HOST WS_HOST H2_HOST)
    
    # 读取 MORE 数据（使用 process substitution 保留空行）
    local -a MORE_ARR
    while IFS= read -r line || [[ -n "$line" ]]; do
        MORE_ARR+=("$line")
    done < <(printf '%s\n' "$IS_JSON_STR" | /tmp/jq -r '(.inbounds[0].streamSettings.network//""),(.inbounds[0].streamSettings.security//""),(.inbounds[0].streamSettings.tcpSettings.header.type//""),(.inbounds[0].streamSettings.kcpSettings.seed//""),(.inbounds[0].streamSettings.kcpSettings.header.type//""),(.inbounds[0].streamSettings.quicSettings.header.type//""),(.inbounds[0].streamSettings.wsSettings.path//""),(.inbounds[0].streamSettings.httpSettings.path//""),(.inbounds[0].streamSettings.grpcSettings.serviceName//"")')
    
    # 读取 HOST 数据（使用 process substitution 保留空行）
    local -a HOST_ARR
    while IFS= read -r line || [[ -n "$line" ]]; do
        HOST_ARR+=("$line")
    done < <(printf '%s\n' "$IS_JSON_STR" | /tmp/jq -r '(.inbounds[0].streamSettings.grpc_host//""),(.inbounds[0].streamSettings.wsSettings.headers.Host//""),(.inbounds[0].streamSettings.httpSettings.host[0]//"")')
    
    # 导出变量
    local -a ALL_JSON_OUTPUT=("${MORE_ARR[@]}" "${HOST_ARR[@]}")
    for i in "${!ALL_JSON_OUTPUT[@]}"; do
        export ${IS_UP_VAR_SET[$i]}="${ALL_JSON_OUTPUT[$i]}"
    done
    
    # 合并 HOST 变量
    local HOST=""
    [[ -z $HOST ]] && HOST="${GRPC_HOST:-${WS_HOST:-${H2_HOST:-}}}"
    
    # 合并 URL_PATH 变量（修复后的逻辑）
    local URL_PATH=""
    [[ -z $URL_PATH && $GRPC_SERVICE_NAME ]] && URL_PATH="$GRPC_SERVICE_NAME"
    [[ -z $URL_PATH && $WS_PATH ]] && URL_PATH="$WS_PATH"
    [[ -z $URL_PATH && $H2_PATH ]] && URL_PATH="$H2_PATH"
    
    echo "NET: $NET (期望：$expected_net)"
    echo "WS_PATH: $WS_PATH"
    echo "H2_PATH: $H2_PATH"
    echo "GRPC_SERVICE_NAME: $GRPC_SERVICE_NAME"
    echo "URL_PATH: $URL_PATH (期望：$expected_path)"
    echo "GRPC_HOST: $GRPC_HOST"
    echo "WS_HOST: $WS_HOST"
    echo "H2_HOST: $H2_HOST"
    echo "HOST: $HOST (期望：$expected_host)"
    
    # 验证
    local pass=true
    [[ "$NET" != "$expected_net" ]] && pass=false && echo "✗ NET 不匹配"
    [[ "$URL_PATH" != "$expected_path" ]] && pass=false && echo "✗ URL_PATH 不匹配"
    [[ "$HOST" != "$expected_host" ]] && pass=false && echo "✗ HOST 不匹配"
    
    if $pass; then
        echo "✓ 测试通过"
        return 0
    else
        echo "✗ 测试失败"
        return 1
    fi
}

# 运行测试
echo ""
echo "=== 运行测试 ==="

test_config "$TEST_CONF_DIR/ws-tls.json" "ws" "/websocket-path" "ws.example.com"
test_config "$TEST_CONF_DIR/grpc-tls.json" "grpc" "grpc-service" "grpc.example.com"
test_config "$TEST_CONF_DIR/h2-tls.json" "h2" "/h2-path" "h2.example.com"

# 清理
rm -rf "$TEST_CONF_DIR"

echo ""
echo "=== 所有测试完成 ==="
