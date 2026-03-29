#!/bin/bash
# 修复版本的 info 功能测试脚本

echo "=== V2Ray Phase 9 - Fixed Info Test ==="
echo ""

# 设置变量
export JQ="/tmp/jq"
export IS_CONF_DIR="/tmp/v2ray-vps-test"

# 测试配置文件
TEST_CONFIG="test-trojan-grpc.json"
JSON_FILE="$IS_CONF_DIR/$TEST_CONFIG"

# 直接执行 jq 解析逻辑
echo "=== 执行 jq 解析 ==="

IS_JSON_STR=$(cat "$JSON_FILE")

IS_JSON_DATA_BASE=$($JQ -r '[.inbounds[0].protocol//"",.inbounds[0].port//"",.inbounds[0].settings.clients[0].id//"",.inbounds[0].settings.clients[0].password//"",.inbounds[0].settings.method//"",.inbounds[0].settings.address//"",.inbounds[0].settings.port//"",.inbounds[0].settings.detour.to//"",.inbounds[0].settings.accounts[0].user//"",.inbounds[0].settings.accounts[0].pass//""] | join(",")' <<<$IS_JSON_STR)

IS_JSON_DATA_MORE=$($JQ -r '[.inbounds[0].streamSettings.network//"",.inbounds[0].streamSettings.security//"",.inbounds[0].streamSettings.tcpSettings.header.type//"",.inbounds[0].streamSettings.kcpSettings.seed//"",.inbounds[0].streamSettings.kcpSettings.header.type//"",.inbounds[0].streamSettings.quicSettings.header.type//"",.inbounds[0].streamSettings.wsSettings.path//"",.inbounds[0].streamSettings.httpSettings.path//"",.inbounds[0].streamSettings.grpcSettings.serviceName//""] | join(",")' <<<$IS_JSON_STR)

echo "BASE: $IS_JSON_DATA_BASE"
echo "MORE: $IS_JSON_DATA_MORE"
echo ""

# 修复方法：使用 mapfile/readarray 读取，这样可以保留空元素
mapfile -t BASE_ARR <<< "$(echo "$IS_JSON_DATA_BASE" | tr ',' '\n')"
mapfile -t MORE_ARR <<< "$(echo "$IS_JSON_DATA_MORE" | tr ',' '\n')"

echo "BASE_ARR (${#BASE_ARR[@]}):"
for i in "${!BASE_ARR[@]}"; do
    echo "  [$i] = '${BASE_ARR[$i]}'"
done
echo ""

echo "MORE_ARR (${#MORE_ARR[@]}):"
for i in "${!MORE_ARR[@]}"; do
    echo "  [$i] = '${MORE_ARR[$i]}'"
done
echo ""

# 变量名称列表
IS_UP_VAR_SET=(IS_PROTOCOL PORT UUID TROJAN_PASSWORD SS_METHOD DOOR_ADDR DOOR_PORT IS_DYNAMIC_PORT IS_SOCKS_USER IS_SOCKS_PASS NET IS_SECURITY TCP_TYPE KCP_SEED KCP_TYPE QUIC_TYPE WS_PATH H2_PATH GRPC_SERVICE_NAME)

echo "IS_UP_VAR_SET (${#IS_UP_VAR_SET[@]}): ${IS_UP_VAR_SET[@]}"
echo ""

# 合并数组
ALL_JSON_OUTPUT=("${BASE_ARR[@]}" "${MORE_ARR[@]}")

echo "ALL_JSON_OUTPUT (${#ALL_JSON_OUTPUT[@]}):"
for i in "${!ALL_JSON_OUTPUT[@]}"; do
    echo "  [$i] = '${ALL_JSON_OUTPUT[$i]}'"
done
echo ""

# 手动赋值
echo "=== 手动赋值 ==="
IS_PROTOCOL="${ALL_JSON_OUTPUT[0]}"
PORT="${ALL_JSON_OUTPUT[1]}"
UUID="${ALL_JSON_OUTPUT[2]}"
TROJAN_PASSWORD="${ALL_JSON_OUTPUT[3]}"
SS_METHOD="${ALL_JSON_OUTPUT[4]}"
DOOR_ADDR="${ALL_JSON_OUTPUT[5]}"
DOOR_PORT="${ALL_JSON_OUTPUT[6]}"
IS_DYNAMIC_PORT="${ALL_JSON_OUTPUT[7]}"
IS_SOCKS_USER="${ALL_JSON_OUTPUT[8]}"
IS_SOCKS_PASS="${ALL_JSON_OUTPUT[9]}"
NET="${ALL_JSON_OUTPUT[10]}"
IS_SECURITY="${ALL_JSON_OUTPUT[11]}"
TCP_TYPE="${ALL_JSON_OUTPUT[12]}"
KCP_SEED="${ALL_JSON_OUTPUT[13]}"
KCP_TYPE="${ALL_JSON_OUTPUT[14]}"
QUIC_TYPE="${ALL_JSON_OUTPUT[15]}"
WS_PATH="${ALL_JSON_OUTPUT[16]}"
H2_PATH="${ALL_JSON_OUTPUT[17]}"
GRPC_SERVICE_NAME="${ALL_JSON_OUTPUT[18]}"

echo "=== 变量检查 ==="
echo "IS_PROTOCOL: '$IS_PROTOCOL'"
echo "PORT: '$PORT'"
echo "UUID: '$UUID'"
echo "NET: '$NET'"
echo "IS_SECURITY: '$IS_SECURITY'"
echo "GRPC_SERVICE_NAME: '$GRPC_SERVICE_NAME'"
echo ""

# Trojan 协议处理
[[ $IS_PROTOCOL == 'trojan' && $TROJAN_PASSWORD ]] && UUID=$TROJAN_PASSWORD

echo "=== 设置 UUID 后 ==="
echo "UUID: '$UUID'"
echo ""

# URL_PATH 设置
[[ -z $URL_PATH && $GRPC_SERVICE_NAME ]] && URL_PATH="$GRPC_SERVICE_NAME"

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