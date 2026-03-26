#!/bin/bash
# 测试 V2Ray 配置修复

set -e

echo "=== 测试配置修复 ==="

# 模拟 get info 函数的关键部分
test_get_info() {
    local JSON_STR='{"inbounds":[{"streamSettings":{"network":"ws","security":"tls","wsSettings":{"path":"/test-path","headers":{"Host":"proxy.example.com"}}}}]}'
    
    # 模拟 jq 查询
    local MORE=$(echo "$JSON_STR" | python3 -c "
import json, sys
data = json.load(sys.stdin)
s = data['inbounds'][0]['streamSettings']
print(s.get('network', ''))
print(s.get('security', ''))
print(s.get('tcpSettings', {}).get('header', {}).get('type', ''))
print(s.get('kcpSettings', {}).get('seed', ''))
print(s.get('kcpSettings', {}).get('header', {}).get('type', ''))
print(s.get('quicSettings', {}).get('header', {}).get('type', ''))
print(s.get('wsSettings', {}).get('path', ''))
print(s.get('httpSettings', {}).get('path', ''))
print(s.get('grpcSettings', {}).get('serviceName', ''))
")
    
    local HOST=$(echo "$JSON_STR" | python3 -c "
import json, sys
data = json.load(sys.stdin)
s = data['inbounds'][0]['streamSettings']
print(s.get('grpc_host', ''))
print(s.get('wsSettings', {}).get('headers', {}).get('Host', ''))
h = s.get('httpSettings', {}).get('host', [''])
print(h[0] if isinstance(h, list) else h)
")
    
    # 模拟 readarray
    local -a MORE_ARRAY
    while IFS= read -r line; do
        MORE_ARRAY+=("$line")
    done <<< "$MORE"
    
    local -a HOST_ARRAY
    while IFS= read -r line; do
        HOST_ARRAY+=("$line")
    done <<< "$HOST"
    
    local NET="${MORE_ARRAY[0]}"
    local IS_TLS="${MORE_ARRAY[1]}"
    local HEADER_TYPE="${MORE_ARRAY[2]}"
    local KCP_SEED="${MORE_ARRAY[3]}"
    local WS_PATH="${MORE_ARRAY[6]}"
    local H2_PATH="${MORE_ARRAY[7]}"
    local GRPC_SERVICE_NAME="${MORE_ARRAY[8]}"
    
    local GRPC_HOST="${HOST_ARRAY[0]}"
    local WS_HOST="${HOST_ARRAY[1]}"
    local H2_HOST="${HOST_ARRAY[2]}"
    
    local URL_PATH=""
    [[ -z $URL_PATH && $GRPC_SERVICE_NAME ]] && URL_PATH="$GRPC_SERVICE_NAME"
    [[ -z $URL_PATH && $WS_PATH ]] && URL_PATH="$WS_PATH"
    [[ -z $URL_PATH && $H2_PATH ]] && URL_PATH="$H2_PATH"
    
    local HOST=""
    [[ -z $HOST && $GRPC_HOST ]] && HOST="$GRPC_HOST"
    [[ -z $HOST && $WS_HOST ]] && HOST="$WS_HOST"
    [[ -z $HOST && $H2_HOST ]] && HOST="$H2_HOST"
    
    echo "NET: $NET"
    echo "IS_TLS: $IS_TLS"
    echo "WS_PATH: $WS_PATH"
    echo "URL_PATH: $URL_PATH"
    echo "WS_HOST: $WS_HOST"
    echo "HOST: $HOST"
    
    # 验证
    if [[ "$URL_PATH" == "/test-path" && "$HOST" == "proxy.example.com" ]]; then
        echo "✓ WS 配置测试通过"
        return 0
    else
        echo "✗ WS 配置测试失败"
        return 1
    fi
}

# 测试 gRPC 配置
test_grpc_config() {
    local JSON_STR='{"inbounds":[{"streamSettings":{"network":"grpc","security":"tls","grpc_host":"proxy.example.com","grpcSettings":{"serviceName":"grpc"}}}]}'
    
    local HOST=$(echo "$JSON_STR" | python3 -c "
import json, sys
data = json.load(sys.stdin)
s = data['inbounds'][0]['streamSettings']
print(s.get('grpc_host', ''))
print(s.get('wsSettings', {}).get('headers', {}).get('Host', ''))
h = s.get('httpSettings', {}).get('host', [''])
print(h[0] if isinstance(h, list) else h)
")
    
    local MORE=$(echo "$JSON_STR" | python3 -c "
import json, sys
data = json.load(sys.stdin)
s = data['inbounds'][0]['streamSettings']
print(s.get('network', ''))
print(s.get('security', ''))
print(s.get('tcpSettings', {}).get('header', {}).get('type', ''))
print(s.get('kcpSettings', {}).get('seed', ''))
print(s.get('kcpSettings', {}).get('header', {}).get('type', ''))
print(s.get('quicSettings', {}).get('header', {}).get('type', ''))
print(s.get('wsSettings', {}).get('path', ''))
print(s.get('httpSettings', {}).get('path', ''))
print(s.get('grpcSettings', {}).get('serviceName', ''))
")
    
    local -a MORE_ARRAY
    while IFS= read -r line; do
        MORE_ARRAY+=("$line")
    done <<< "$MORE"
    
    local -a HOST_ARRAY
    while IFS= read -r line; do
        HOST_ARRAY+=("$line")
    done <<< "$HOST"
    
    local GRPC_SERVICE_NAME="${MORE_ARRAY[8]}"
    local GRPC_HOST="${HOST_ARRAY[0]}"
    
    local URL_PATH=""
    [[ -z $URL_PATH && $GRPC_SERVICE_NAME ]] && URL_PATH="$GRPC_SERVICE_NAME"
    
    local HOST=""
    [[ -z $HOST && $GRPC_HOST ]] && HOST="$GRPC_HOST"
    
    echo "GRPC_SERVICE_NAME: $GRPC_SERVICE_NAME"
    echo "GRPC_HOST: $GRPC_HOST"
    echo "URL_PATH: $URL_PATH"
    echo "HOST: $HOST"
    
    if [[ "$URL_PATH" == "grpc" && "$HOST" == "proxy.example.com" ]]; then
        echo "✓ gRPC 配置测试通过"
        return 0
    else
        echo "✗ gRPC 配置测试失败"
        return 1
    fi
}

# 运行测试
test_get_info
echo ""
test_grpc_config

echo ""
echo "=== 所有测试完成 ==="
