#!/bin/bash
# Phase 9 辅助函数测试脚本
# 用于测试 JSON 生成辅助函数

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQ="/tmp/jq"
[[ -x "$JQ" ]] || JQ="jq"
export JQ

source "$SCRIPT_DIR/core.sh"

echo "=== Phase 9 辅助函数测试 ==="
echo

# 测试 generate_protocol_settings
echo "1. 测试 generate_protocol_settings (vmess):"
result=$(generate_protocol_settings "vmess" "test-uuid-123" "")
echo "$result" | $JQ .
echo

echo "2. 测试 generate_protocol_settings (vless):"
result=$(generate_protocol_settings "vless" "test-uuid-456" "")
echo "$result" | $JQ .
echo

echo "3. 测试 generate_protocol_settings (trojan):"
result=$(generate_protocol_settings "trojan" "" "test-password-789")
echo "$result" | $JQ .
echo

echo "4. 测试 generate_protocol_settings (shadowsocks):"
result=$(generate_protocol_settings "shadowsocks" "" "test-ss-password")
echo "$result" | $JQ .
echo

# 测试 generate_client_settings
echo "5. 测试 generate_client_settings (vmess):"
result=$(generate_client_settings "vmess" "client-uuid" "")
echo "$result" | $JQ .
echo

# 测试 generate_sniffing
echo "6. 测试 generate_sniffing:"
result=$(generate_sniffing)
echo "$result" | $JQ .
echo

# 测试 generate_stream_settings
echo "7. 测试 generate_stream_settings:"
result=$(generate_stream_settings "ws" "tls" "example.com" "/path")
echo "$result" | $JQ .
echo

# 验证 JSON 有效性
echo "=== JSON 有效性验证 ==="
test_json_validity() {
    local json="$1"
    local description="$2"
    
    if echo "$json" | $JQ . > /dev/null 2>&1; then
        echo "✅ $description: 有效 JSON"
        return 0
    else
        echo "❌ $description: 无效 JSON"
        echo "   内容：$json"
        return 1
    fi
}

test_json_validity "$(generate_protocol_settings 'vmess' 'uuid' '')" "VMess 协议设置"
test_json_validity "$(generate_protocol_settings 'vless' 'uuid' '')" "VLESS 协议设置"
test_json_validity "$(generate_protocol_settings 'trojan' '' 'password')" "Trojan 协议设置"
test_json_validity "$(generate_protocol_settings 'shadowsocks' '' 'password')" "Shadowsocks 协议设置"
test_json_validity "$(generate_sniffing)" "嗅探配置"
test_json_validity "$(generate_stream_settings 'ws' 'tls' 'host' '/path')" "传输层设置"

echo
echo "=== 测试完成 ==="
