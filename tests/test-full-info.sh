#!/bin/bash
# 完整的 info 功能测试脚本（模拟 VPS 环境）

echo "=== V2Ray Phase 9 - Full Info Function Test ==="
echo ""

# 设置变量
export JQ="/tmp/jq"
export IS_CONF_DIR="/tmp/v2ray-vps-test"

# 加载 core.sh 中的 get 函数定义
source src/core.sh 2>/dev/null || {
    echo "❌ 无法加载 core.sh"
    exit 1
}

# 测试配置文件
TEST_CONFIG="test-trojan-grpc.json"

echo "=== 测试配置文件 ==="
cat $IS_CONF_DIR/$TEST_CONFIG
echo ""

echo "=== 测试 get info 命令 ==="
get info $TEST_CONFIG

echo ""
echo "=== 变量检查 ==="
echo "IS_PROTOCOL: $IS_PROTOCOL"
echo "PORT: $PORT"
echo "UUID: $UUID"
echo "NET: $NET"
echo "HOST: $HOST"
echo "URL_PATH: $URL_PATH"
echo "TROJAN_PASSWORD: $TROJAN_PASSWORD"
echo "IS_SECURITY: $IS_SECURITY"
echo "GRPC_SERVICE_NAME: $GRPC_SERVICE_NAME"

echo ""
echo "=== 验证结果 ==="
if [[ "$IS_PROTOCOL" == "trojan" ]]; then
    echo "✓ IS_PROTOCOL: trojan"
else
    echo "✗ IS_PROTOCOL: 期望 trojan, 实际 $IS_PROTOCOL"
fi

if [[ "$PORT" == "443" ]]; then
    echo "✓ PORT: 443"
else
    echo "✗ PORT: 期望 443, 实际 $PORT"
fi

if [[ "$TROJAN_PASSWORD" == "975a95b5-694d-45c6-8de4-eafa6607c247" ]]; then
    echo "✓ TROJAN_PASSWORD: correct"
else
    echo "✗ TROJAN_PASSWORD: 期望 975a95b5-694d-45c6-8de4-eafa6607c247, 实际 $TROJAN_PASSWORD"
fi

if [[ "$NET" == "grpc" ]]; then
    echo "✓ NET: grpc"
else
    echo "✗ NET: 期望 grpc, 实际 $NET"
fi

if [[ "$IS_SECURITY" == "tls" ]]; then
    echo "✓ IS_SECURITY: tls"
else
    echo "✗ IS_SECURITY: 期望 tls, 实际 $IS_SECURITY"
fi

if [[ "$GRPC_SERVICE_NAME" == "grpc" ]]; then
    echo "✓ GRPC_SERVICE_NAME: grpc"
else
    echo "✗ GRPC_SERVICE_NAME: 期望 grpc, 实际 $GRPC_SERVICE_NAME"
fi

if [[ "$URL_PATH" == "grpc" ]]; then
    echo "✓ URL_PATH: grpc"
else
    echo "✗ URL_PATH: 期望 grpc, 实际 $URL_PATH"
fi

echo ""
echo "=== Troja URL 生成检查 ==="
if [[ "$UUID" == "$TROJAN_PASSWORD" ]]; then
    echo "✓ UUID 已从 TROJAN_PASSWORD 赋值"
else
    echo "✗ UUID 未从 TROJAN_PASSWORD 赋值"
fi

echo ""
echo "=== 完成 ==="