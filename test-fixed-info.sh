#!/bin/bash
# 测试修复后的 info 功能

echo "=== Testing Fixed info() Function ==="
echo ""

# 设置变量
export JQ="/tmp/jq"
export IS_CONF_DIR="/tmp/v2ray-vps-test"

# 创建测试配置
mkdir -p $IS_CONF_DIR
cat > $IS_CONF_DIR/test-trojan-grpc.json << 'EOF'
{
  "inbounds": [
    {
      "tag": "test",
      "port": 443,
      "protocol": "trojan",
      "listen": "0.0.0.0",
      "settings": {
        "clients": [
          {
            "password": "975a95b5-694d-45c6-8de4-eafa6607c247"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "security": "tls",
        "grpcSettings": {
          "serviceName": "grpc"
        },
        "tlsSettings": {
          "serverName": "proxy.yourdie.com"
        }
      }
    }
  ]
}
EOF

# 运行测试并验证
bash << 'TEST_SCRIPT'
# 设置变量
export JQ="/tmp/jq"
export IS_CONF_DIR="/tmp/v2ray-vps-test"

# 加载 core.sh
source src/core.sh

# 执行 get info
get info test-trojan-grpc.json

# 检查变量
echo "=== 变量检查 ==="
echo "IS_PROTOCOL: $IS_PROTOCOL"
echo "PORT: $PORT"
echo "UUID: $UUID"
echo "NET: $NET"
echo "IS_SECURITY: $IS_SECURITY"
echo "GRPC_SERVICE_NAME: $GRPC_SERVICE_NAME"
echo "URL_PATH: $URL_PATH"
echo "TROJAN_PASSWORD: $TROJAN_PASSWORD"
echo ""

# 验证结果
echo "=== 验证结果 ==="
ERRORS=0

if [[ "$IS_PROTOCOL" != "trojan" ]]; then
    echo "✗ IS_PROTOCOL: 期望 trojan, 实际 '$IS_PROTOCOL'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ IS_PROTOCOL: trojan"
fi

if [[ "$PORT" != "443" ]]; then
    echo "✗ PORT: 期望 443, 实际 '$PORT'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ PORT: 443"
fi

if [[ "$TROJAN_PASSWORD" != "975a95b5-694d-45c6-8de4-eafa6607c247" ]]; then
    echo "✗ TROJAN_PASSWORD: 期望 975a95b5-694d-45c6-8de4-eafa6607c247, 实际 '$TROJAN_PASSWORD'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ TROJAN_PASSWORD: correct"
fi

if [[ "$NET" != "grpc" ]]; then
    echo "✗ NET: 期望 grpc, 实际 '$NET'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ NET: grpc"
fi

if [[ "$IS_SECURITY" != "tls" ]]; then
    echo "✗ IS_SECURITY: 期望 tls, 实际 '$IS_SECURITY'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ IS_SECURITY: tls"
fi

if [[ "$GRPC_SERVICE_NAME" != "grpc" ]]; then
    echo "✗ GRPC_SERVICE_NAME: 期望 grpc, 实际 '$GRPC_SERVICE_NAME'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ GRPC_SERVICE_NAME: grpc"
fi

if [[ "$URL_PATH" != "grpc" ]]; then
    echo "✗ URL_PATH: 期望 grpc, 实际 '$URL_PATH'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ URL_PATH: grpc"
fi

echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ $ERRORS test(s) failed"
    exit 1
fi
TEST_SCRIPT