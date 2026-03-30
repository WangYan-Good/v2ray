#!/bin/bash
set -e

echo "=== V2Ray Phase 9 - Info Fix Verification ==="
echo ""

# Check jq is available
if ! command -v /tmp/jq &>/dev/null; then
    echo "❌ jq not found at /tmp/jq"
    exit 1
fi

echo "✓ jq found: $(/tmp/jq --version)"
echo ""

# Create test config
mkdir -p /tmp/v2ray-test
cat > /tmp/v2ray-test/test-config.json << 'EOF'
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

echo "✓ Test config created"
echo ""

# Test jq parsing
echo "=== Testing jq parsing ==="

JSON_FILE="/tmp/v2ray-test/test-config.json"

BASE=$(/tmp/jq -r '[.inbounds[0].protocol//"",.inbounds[0].port//"",.inbounds[0].settings.clients[0].id//"",.inbounds[0].settings.clients[0].password//"",.inbounds[0].settings.method//"",.inbounds[0].settings.address//"",.inbounds[0].settings.port//"",.inbounds[0].settings.detour.to//"",.inbounds[0].settings.accounts[0].user//"",.inbounds[0].settings.accounts[0].pass//""] | join(",")' "$JSON_FILE")

MORE=$(/tmp/jq -r '[.inbounds[0].streamSettings.network//"",.inbounds[0].streamSettings.security//"",.inbounds[0].streamSettings.tcpSettings.header.type//"",.inbounds[0].streamSettings.kcpSettings.seed//"",.inbounds[0].streamSettings.kcpSettings.header.type//"",.inbounds[0].streamSettings.quicSettings.header.type//"",.inbounds[0].streamSettings.wsSettings.path//"",.inbounds[0].streamSettings.httpSettings.path//"",.inbounds[0].streamSettings.grpcSettings.serviceName//""] | join(",")' "$JSON_FILE")

HOST=$(/tmp/jq -r '[.inbounds[0].streamSettings.grpc_host//"",.inbounds[0].streamSettings.wsSettings.headers.Host//"",.inbounds[0].streamSettings.httpSettings.host[0]//""] | join(",")' "$JSON_FILE")

REALITY=$(/tmp/jq -r '[.inbounds[0].streamSettings.realitySettings.serverNames[0]//"",.inbounds[0].streamSettings.realitySettings.publicKey//"",.inbounds[0].streamSettings.realitySettings.privateKey//""] | join(",")' "$JSON_FILE")

echo "BASE output: $BASE"
echo "MORE output: $MORE"
echo "HOST output: $HOST"
echo "REALITY output: $REALITY"
echo ""

# Parse arrays
IFS=',' read -r -a BASE_ARR <<< "$BASE"
IFS=',' read -r -a MORE_ARR <<< "$MORE"
IFS=',' read -r -a HOST_ARR <<< "$HOST"
IFS=',' read -r -a REALITY_ARR <<< "$REALITY"

# Set variables
IS_PROTOCOL="${BASE_ARR[0]}"
PORT="${BASE_ARR[1]}"
UUID="${BASE_ARR[2]}"
TROJAN_PASSWORD="${BASE_ARR[3]}"
SS_METHOD="${BASE_ARR[4]}"
DOOR_ADDR="${BASE_ARR[5]}"
DOOR_PORT="${BASE_ARR[6]}"
IS_DYNAMIC_PORT="${BASE_ARR[7]}"
IS_SOCKS_USER="${BASE_ARR[8]}"
IS_SOCKS_PASS="${BASE_ARR[9]}"

NET="${MORE_ARR[0]}"
IS_SECURITY="${MORE_ARR[1]}"
TCP_TYPE="${MORE_ARR[2]}"
KCP_SEED="${MORE_ARR[3]}"
KCP_TYPE="${MORE_ARR[4]}"
QUIC_TYPE="${MORE_ARR[5]}"
WS_PATH="${MORE_ARR[6]}"
H2_PATH="${MORE_ARR[7]}"
GRPC_SERVICE_NAME="${MORE_ARR[8]}"

GRPC_HOST="${HOST_ARR[0]}"
WS_HOST="${HOST_ARR[1]}"
H2_HOST="${HOST_ARR[2]}"

IS_SERVERNAME="${REALITY_ARR[0]}"
IS_PUBLIC_KEY="${REALITY_ARR[1]}"
IS_PRIVATE_KEY="${REALITY_ARR[2]}"

# Unset empty variables
for v in IS_PROTOCOL PORT UUID TROJAN_PASSWORD SS_METHOD DOOR_ADDR DOOR_PORT IS_DYNAMIC_PORT IS_SOCKS_USER IS_SOCKS_PASS NET IS_SECURITY TCP_TYPE KCP_SEED KCP_TYPE QUIC_TYPE WS_PATH H2_PATH GRPC_SERVICE_NAME GRPC_HOST WS_HOST H2_HOST IS_SERVERNAME IS_PUBLIC_KEY IS_PRIVATE_KEY; do
    [[ -z "${!v}" || "${!v}" == "null" ]] && unset $v
done

# Show results
echo "=== Variables after parsing ==="
echo "IS_PROTOCOL: $IS_PROTOCOL"
echo "PORT: $PORT"
echo "UUID: $UUID"
echo "TROJAN_PASSWORD: $TROJAN_PASSWORD"
echo "NET: $NET"
echo "IS_SECURITY: $IS_SECURITY"
echo "WS_PATH: $WS_PATH"
echo "H2_PATH: $H2_PATH"
echo "GRPC_SERVICE_NAME: $GRPC_SERVICE_NAME"
echo "GRPC_HOST: $GRPC_HOST"
echo "WS_HOST: $WS_HOST"
echo "H2_HOST: $H2_HOST"
echo ""

# Set URL_PATH
[[ -z $URL_PATH && $GRPC_SERVICE_NAME ]] && URL_PATH="$GRPC_SERVICE_NAME"
[[ -z $URL_PATH && $WS_PATH ]] && URL_PATH="$WS_PATH"
[[ -z $URL_PATH && $H2_PATH ]] && URL_PATH="$H2_PATH"

echo "URL_PATH: $URL_PATH"
echo ""

# Verify expected values
echo "=== Verification ==="
ERRORS=0

if [[ "$IS_PROTOCOL" != "trojan" ]]; then
    echo "❌ IS_PROTOCOL should be 'trojan', got '$IS_PROTOCOL'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ IS_PROTOCOL: trojan"
fi

if [[ "$PORT" != "443" ]]; then
    echo "❌ PORT should be '443', got '$PORT'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ PORT: 443"
fi

if [[ "$TROJAN_PASSWORD" != "975a95b5-694d-45c6-8de4-eafa6607c247" ]]; then
    echo "❌ TROJAN_PASSWORD mismatch"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ TROJAN_PASSWORD: correct"
fi

if [[ "$NET" != "grpc" ]]; then
    echo "❌ NET should be 'grpc', got '$NET'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ NET: grpc"
fi

if [[ "$IS_SECURITY" != "tls" ]]; then
    echo "❌ IS_SECURITY should be 'tls', got '$IS_SECURITY'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ IS_SECURITY: tls"
fi

if [[ "$GRPC_SERVICE_NAME" != "grpc" ]]; then
    echo "❌ GRPC_SERVICE_NAME should be 'grpc', got '$GRPC_SERVICE_NAME'"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ GRPC_SERVICE_NAME: grpc"
fi

if [[ "$URL_PATH" != "grpc" ]]; then
    echo "❌ URL_PATH should be 'grpc', got '$URL_PATH'"
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