#!/usr/bin/env bats
#
# caddy.sh Caddy 配置功能单元测试
#

setup() {
    source "$BATS_TEST_DIRNAME/../helpers/test_helper.sh"
    
    # 创建临时测试目录
    export TEST_TMP_DIR="/tmp/v2ray_caddy_test_$$"
    mkdir -p "$TEST_TMP_DIR"/{caddy,caddy/WangYan-Good,ssl}
    
    # 临时覆盖路径变量
    export IS_CADDY_DIR="$TEST_TMP_DIR/caddy"
    export IS_CADDY_CONF="$TEST_TMP_DIR/caddy/WangYan-Good"
    export IS_CADDY_BIN="$TEST_TMP_DIR/bin/caddy"
    export IS_CADDYFILE="$IS_CADDY_DIR/Caddyfile"
    
    # 设置 Caddy 所需的默认端口变量
    export IS_HTTP_PORT="80"
    export IS_HTTPS_PORT="443"
    
    mkdir -p "$IS_CADDY_CONF"
    
    # 创建空的 Caddyfile
    touch "$IS_CADDYFILE"
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

@test "caddy_config new - 应该创建新的 Caddy 配置" {
    load_core_functions
    source "$IS_SH_DIR/src/caddy.sh"
    
    export HOST="example.com"
    export PORT="8080"
    export URL_PATH="/v2ray"
    
    run caddy_config new
    [[ "$status" -eq 0 ]]
}

@test "caddy_config del - 应该删除 Caddy 配置" {
    load_core_functions
    source "$IS_SH_DIR/src/caddy.sh"
    
    export HOST="example.com"
    
    # 先创建测试配置文件 (使用正确的命名格式：HOST.conf)
    cat > "$IS_CADDY_CONF/${HOST}.conf" <<EOF
example.com {
    reverse_proxy /v2ray* localhost:8080
}
EOF
    
    # 添加 import 到 Caddyfile
    echo "import $IS_CADDY_CONF/*.conf" >> "$IS_CADDYFILE"
    
    run caddy_config del
    [[ "$status" -eq 0 ]]
    [[ ! -f "$IS_CADDY_CONF/${HOST}.conf" ]]
}

@test "caddy_config - 应该为 ws 协议创建配置" {
    load_core_functions
    source "$IS_SH_DIR/src/caddy.sh"
    
    export HOST="example.com"
    export PORT="8080"
    export URL_PATH="/v2ray"
    
    run caddy_config ws
    [[ "$status" -eq 0 ]]
    [[ -f "$IS_CADDY_CONF/example.com.conf" ]]
}

@test "caddy_config - 应该为 grpc 协议创建配置" {
    load_core_functions
    source "$IS_SH_DIR/src/caddy.sh"
    
    export HOST="example.com"
    export PORT="8080"
    export URL_PATH="/v2ray"
    
    run caddy_config grpc
    [[ "$status" -eq 0 ]]
    [[ -f "$IS_CADDY_CONF/example.com.conf" ]]
}
