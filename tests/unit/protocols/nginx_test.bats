#!/usr/bin/env bats
#
# nginx.sh Nginx 配置功能单元测试
#

setup() {
    source "$BATS_TEST_DIRNAME/../helpers/test_helper.sh"
    
    # 创建临时测试目录
    export TEST_TMP_DIR="/tmp/v2ray_nginx_test_$$"
    mkdir -p "$TEST_TMP_DIR"/{nginx,ssl}
    
    # 临时覆盖路径变量
    export IS_NGINX_DIR="$TEST_TMP_DIR/nginx"
    export IS_NGINX_CONF="$TEST_TMP_DIR/nginx/v2ray"
    export IS_NGINX_BIN="$TEST_TMP_DIR/nginx/bin"  # Mock nginx binary path
    export IS_NGINXFILE="$IS_NGINX_DIR/nginx.conf"
    export HOST="test.example.com"
    
    mkdir -p "$IS_NGINX_CONF"
    
    # Create mock nginx binary
    echo '#!/bin/bash' > "$IS_NGINX_BIN"
    echo 'exit 0' >> "$IS_NGINX_BIN"
    chmod +x "$IS_NGINX_BIN"
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

@test "nginx_config new - 应该创建新的 Nginx 配置" {
    load_core_functions
    source "$IS_SH_DIR/src/nginx.sh"
    
    export HOST="example.com"
    export PORT="8080"
    export URL_PATH="/v2ray"
    
    # 模拟 certbot 和 nginx 命令
    certbot() { return 0; }
    
    run nginx_config new "" "$URL_PATH" "$PORT"
    [[ "$status" -eq 0 ]]
}

@test "nginx_config del - 应该删除 Nginx 配置" {
    load_core_functions
    source "$IS_SH_DIR/src/nginx.sh"
    
    # 先创建测试配置文件 (使用正确的命名格式：protocol-HOST.conf)
    cat > "$IS_NGINX_CONF/VMess-${HOST}.conf" <<EOF
server {
    listen 80;
    server_name test.example.com;
}
EOF
    
    run nginx_config del
    [[ "$status" -eq 0 ]]
    [[ ! -f "$IS_NGINX_CONF/VMess-${HOST}.conf" ]]
}

@test "nginx_reload - 应该重载 Nginx 配置" {
    load_core_functions
    source "$IS_SH_DIR/src/nginx.sh"
    
    # Mock pgrep to simulate nginx is running
    pgrep() { return 0; }
    
    # Create a proper mock nginx script that handles -s reload
    cat > "$IS_NGINX_BIN" <<'EOF'
#!/bin/bash
if [[ "$1" == "-s" && "$2" == "reload" ]]; then
    exit 0
fi
exit 0
EOF
    chmod +x "$IS_NGINX_BIN"
    
    run nginx_reload
    [[ "$status" -eq 0 ]]
}
