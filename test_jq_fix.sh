#!/bin/bash
# Test script for Phase 9 jq fix
# Tests the variable expansion fix for JSON_STR and IS_SNIFFING

set -e

echo "=== Testing jq variable expansion fix ==="
echo

# Test 1: Check if jq is available
if ! command -v jq &>/dev/null; then
    echo "❌ jq is not available in this environment"
    echo "   This test script should be run on the VPS where jq is installed"
    exit 1
fi

echo "✓ jq found: $(jq --version)"
echo

# Test 2: Test the fixed expression
echo "=== Test 2: Fixed jq expression ==="
JSON_STR='settings:{clients:[{id:"test-uuid"}]},streamSettings:{network:"h2",security:"tls",httpSettings:{path:"/test"}}'
IS_SNIFFING=$(jq -n '{
    enabled: true,
    destOverride: ["http", "tls"]
}')
IS_CONFIG_NAME="test-config"
PORT=443
IS_LISTEN='"listen": "127.0.0.1"'
IS_PROTOCOL="trojan"

echo "Testing: $JSON_STR"
echo "IS_SNIFFING: $IS_SNIFFING"
echo

RESULT=$(jq --argjson settings "{$JSON_STR}" --argjson sniffing "$IS_SNIFFING" \
    "{inbounds:[{tag:\"$IS_CONFIG_NAME\",port:$PORT,$IS_LISTEN,protocol:\"$IS_PROTOCOL\", \$settings, \$sniffing}]}" <<<{})

echo "Result:"
echo "$RESULT" | jq '.'
echo

# Test 3: Test dynamic port expression
echo "=== Test 3: Dynamic port expression ==="
IS_STREAM='streamSettings:{network:"grpc",grpc_host:"example.com",security:"tls",grpcSettings:{serviceName:"grpc"}}'
IS_DYNAMIC_PORT_RANGE="20000-30000"

RESULT=$(jq --argjson stream "$IS_STREAM" --argjson sniffing "$IS_SNIFFING" \
    "{inbounds:[{tag:\"$IS_CONFIG_NAME-link.json\",port:\"$IS_DYNAMIC_PORT_RANGE\",$IS_LISTEN,protocol:\"vmess\", streamSettings: \$stream, \$sniffing, allocate:{strategy:\"random\"}}]}" <<<{})

echo "Result:"
echo "$RESULT" | jq '.'
echo

# Test 4: Verify the JSON structure
echo "=== Test 4: Verify JSON structure ==="
echo "Checking for required fields..."

if echo "$RESULT" | jq -e '.inbounds | length > 0' &>/dev/null; then
    echo "✓ Has inbounds array"
else
    echo "❌ Missing inbounds array"
fi

if echo "$RESULT" | jq -e '.inbounds[0].protocol' &>/dev/null; then
    echo "✓ Has protocol field"
else
    echo "❌ Missing protocol field"
fi

if echo "$RESULT" | jq -e '.inbounds[0].sniffing' &>/dev/null; then
    echo "✓ Has sniffing field"
else
    echo "❌ Missing sniffing field"
fi

if echo "$RESULT" | jq -e '.inbounds[0].settings' &>/dev/null; then
    echo "✓ Has settings field"
else
    echo "❌ Missing settings field"
fi

if echo "$RESULT" | jq -e '.inbounds[0].streamSettings' &>/dev/null; then
    echo "✓ Has streamSettings field"
else
    echo "❌ Missing streamSettings field"
fi

echo
echo "=== All tests completed ==="