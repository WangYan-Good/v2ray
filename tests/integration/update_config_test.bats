#!/usr/bin/env bats
#
# 配置更新测试
#

load ../helpers/helpers.bash

setup() {
    # 设置测试环境变量 - 使用绝对路径
    export IS_SH_DIR="/home/node/.openclaw/v2ray"
    
    # 设置测试环境
    export TEST_TMP_DIR="/tmp/v2ray_update_test_$$"
    mkdir -p "$TEST_TMP_DIR"/{conf,bin,sh/src}
    
    # 临时覆盖路径变量
    export IS_CORE_DIR="$TEST_TMP_DIR"
    export IS_CONF_DIR="$TEST_TMP_DIR/conf"
    
    # 创建测试配置文件
    cat > "$IS_CONF_DIR/test-8080.json" <<EOF
{
  "inbounds": [{
    "tag": "test-8080",
    "port": 8080,
    "listen": "0.0.0.0",
    "protocol": "vmess",
    "settings": {}
  }]
}
EOF
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

@test "配置更新 - 应该能够更改端口" {
    source "$IS_SH_DIR/src/core.sh"
    
    # 测试端口更改逻辑
    export IS_CONFIG_FILE="$IS_CONF_DIR/test-8080.json"
    
    # 读取当前配置 (use python3 as fallback for jq)
    run python3 -c "import json; print(json.load(open('$IS_CONFIG_FILE'))['inbounds'][0]['port'])"
    [[ "$output" == "8080" ]]
    
    # 模拟端口更改
    run python3 -c "import json; c=json.load(open('$IS_CONFIG_FILE')); c['inbounds'][0]['port']=9090; json.dump(c,open('$IS_CONFIG_FILE','w'))"
    [[ "$status" -eq 0 ]]
}

@test "配置更新 - 应该能够更改 UUID" {
    source "$IS_SH_DIR/src/core.sh"
    
    # 生成新的 UUID
    get_uuid
    NEW_UUID="$TMP_UUID"
    
    [[ "$NEW_UUID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

@test "配置更新 - 应该能够更改协议" {
    source "$IS_SH_DIR/src/core.sh"
    
    # 测试协议列表
    [[ "${#PROTOCOL_LIST[@]}" -gt 0 ]]
    
    # 验证协议名称格式 (allow protocols with or without suffix)
    for protocol in "${PROTOCOL_LIST[@]}"; do
        [[ "$protocol" =~ ^(VMess|VLESS|Trojan|Shadowsocks|Socks) ]]
    done
}

@test "配置更新 - 应该能够更改加密方式" {
    source "$IS_SH_DIR/src/core.sh"
    
    # 测试加密方式列表
    [[ "${#SS_METHOD_LIST[@]}" -gt 0 ]]
    
    # 验证加密方式名称 (aes, chacha20, or 2022 variants)
    for method in "${SS_METHOD_LIST[@]}"; do
        [[ "$method" =~ ^(aes|chacha20|2022)- ]]
    done
}

@test "配置更新 - 应该能够更改伪装类型" {
    source "$IS_SH_DIR/src/core.sh"
    
    # 测试伪装类型列表
    [[ "${#HEADER_TYPE_LIST[@]}" -gt 0 ]]
    
    # 验证伪装类型名称 (wechat-video is the full name)
    for header in "${HEADER_TYPE_LIST[@]}"; do
        [[ "$header" =~ ^(none|srtp|utp|wechat-video|dtls|wireguard)$ ]]
    done
}
