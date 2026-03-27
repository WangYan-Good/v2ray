#!/bin/bash
# 直接测试修复后的 jq 提取逻辑

echo "=== V2Ray Phase 9 - Fix Verification ==="
echo ""

# 设置变量
export JQ="/tmp/jq"
JSON_FILE="/tmp/v2ray-vps-test/test-trojan-grpc.json"

# 创建测试配置
mkdir -p /tmp/v2ray-vps-test
cat > $JSON_FILE << 'EOF'
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

# 逐个提取字段（修复后的方法）
echo "=== 逐个提取字段 ==="
IS_PROTOCOL=$($JQ -r '.inbounds[0].protocol // ""' "$JSON_FILE")
PORT=$($JQ -r '.inbounds[0].port // ""' "$JSON_FILE")
UUID=$($JQ -r '.inbounds[0].settings.clients[0].id // ""' "$JSON_FILE")
TROJAN_PASSWORD=$($JQ -r '.inbounds[0].settings.clients[0].password // ""' "$JSON_FILE")
SS_METHOD=$($JQ -r '.inbounds[0].settings.method // ""' "$JSON_FILE")
DOOR_ADDR=$($JQ -r '.inbounds[0].settings.address // ""' "$JSON_FILE")
DOOR_PORT=$($JQ -r '.inbounds[0].settings.port // ""' "$JSON_FILE")
IS_DYNAMIC_PORT=$($JQ -r '.inbounds[0].settings.detour.to // ""' "$JSON_FILE")
IS_SOCKS_USER=$($JQ -r '.inbounds[0].settings.accounts[0].user // ""' "$JSON_FILE")
IS_SOCKS_PASS=$($JQ -r '.inbounds[0].settings.accounts[0].pass // ""' "$JSON_FILE")
NET=$($JQ -r '.inbounds[0].streamSettings.network // ""' "$JSON_FILE")
IS_SECURITY=$($JQ -r '.inbounds[0].streamSettings.security // ""' "$JSON_FILE")
TCP_TYPE=$($JQ -r '.inbounds[0].streamSettings.tcpSettings.header.type // ""' "$JSON_FILE")
KCP_SEED=$($JQ -r '.inbounds[0].streamSettings.kcpSettings.seed // ""' "$JSON_FILE")
KCP_TYPE=$($JQ -r '.inbounds[0].streamSettings.kcpSettings.header.type // ""' "$JSON_FILE")
QUIC_TYPE=$($JQ -r '.inbounds[0].streamSettings.quicSettings.header.type // ""' "$JSON_FILE")
WS_PATH=$($JQ -r '.inbounds[0].streamSettings.wsSettings.path // ""' "$JSON_FILE")
H2_PATH=$($JQ -r '.inbounds[0].streamSettings.httpSettings.path // ""' "$JSON_FILE")
GRPC_SERVICE_NAME=$($JQ -r '.inbounds[0].streamSettings.grpcSettings.serviceName // ""' "$JSON_FILE")
GRPC_HOST=$($JQ -r '.inbounds[0].streamSettings.grpc_host // ""' "$JSON_FILE")
WS_HOST=$($JQ -r '.inbounds[0].streamSettings.wsSettings.headers.Host // ""' "$JSON_FILE")
H2_HOST=$($JQ -r '.inbounds[0].streamSettings.httpSettings.host[0] // ""' "$JSON_FILE")
IS_SERVERNAME=$($JQ -r '.inbounds[0].streamSettings.realitySettings.serverNames[0] // ""' "$JSON_FILE")
IS_PUBLIC_KEY=$($JQ -r '.inbounds[0].streamSettings.realitySettings.publicKey // ""' "$JSON_FILE")
IS_PRIVATE_KEY=$($JQ -r '.inbounds[0].streamSettings.realitySettings.privateKey // ""' "$JSON_FILE")

echo "=== 变量检查 ==="
echo "IS_PROTOCOL: '$IS_PROTOCOL'"
echo "PORT: '$PORT'"
echo "UUID: '$UUID'"
echo "NET: '$NET'"
echo "IS_SECURITY: '$IS_SECURITY'"
echo "GRPC_SERVICE_NAME: '$GRPC_SERVICE_NAME'"
echo "TROJAN_PASSWORD: '$TROJAN_PASSWORD'"
echo ""

# Trojan 协议处理
[[ $IS_PROTOCOL == 'trojan' && $TROJAN_PASSWORD ]] && UUID=$TROJAN_PASSWORD

# URL_PATH 设置
[[ -z $URL_PATH && $GRPC_SERVICE_NAME ]] && URL_PATH="$GRPC_SERVICE_NAME"

echo "=== 处理后 ==="
echo "UUID: '$UUID'"
echo "URL_PATH: '$URL_PATH'"
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