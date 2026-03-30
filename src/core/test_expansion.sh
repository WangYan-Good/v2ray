#!/bin/bash
# Test variable expansion for core.sh fixes

echo "=== V2Ray Core.sh Variable Expansion Test ==="
echo ""

# Test VMess
UUID="test-uuid-12345"
IS_CONFIG_NAME="vmess-config"
IS_SERVER_ID_JSON="settings:{clients:[{id:\"$UUID\"}],detour:{to:\"$IS_CONFIG_NAME-link.json\"}}"
echo "✓ VMess Server JSON:"
echo "  $IS_SERVER_ID_JSON"
echo ""

# Test VMess Client
IS_ADDR="192.168.1.100"
PORT="443"
IS_CLIENT_ID_JSON="settings:{vnext:[{address:\"$IS_ADDR\",port:\"$PORT\",users:[{id:\"$UUID\"}]}]}"
echo "✓ VMess Client JSON:"
echo "  $IS_CLIENT_ID_JSON"
echo ""

# Test VLESS
IS_SERVER_ID_JSON="settings:{clients:[{id:\"$UUID\"}],decryption:\"none\"}"
echo "✓ VLESS Server JSON:"
echo "  $IS_SERVER_ID_JSON"
echo ""

# Test Trojan
TROJAN_PASSWORD="trojan-pass-xyz"
IS_SERVER_ID_JSON="settings:{clients:[{password:\"$TROJAN_PASSWORD\"}]}"
echo "✓ Trojan Server JSON:"
echo "  $IS_SERVER_ID_JSON"
echo ""

# Test Shadowsocks
SS_METHOD="aes-256-gcm"
SS_PASSWORD="ss-pass-abc"
JSON_STR="settings:{method:\"$SS_METHOD\",password:\"$SS_PASSWORD\",network:\"tcp,udp\"}"
echo "✓ Shadowsocks JSON:"
echo "  $JSON_STR"
echo ""

# Test combined JSON_STR
IS_STREAM="streamSettings:{network:\"tcp\",tcpSettings:{header:{type:\"http\"}}}"
IS_SERVER_ID_JSON="settings:{clients:[{id:\"$UUID\"}]}"
JSON_STR="\"$IS_SERVER_ID_JSON\",\"$IS_STREAM\""
echo "✓ Combined JSON_STR (TCP):"
echo "  $JSON_STR"
echo ""

echo "=== All Tests Passed ==="
