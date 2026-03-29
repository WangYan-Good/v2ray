#!/usr/bin/env bash
#
# 测试辅助函数
#

# 获取测试目录的绝对路径
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH_DIR="$(dirname "$TESTS_DIR")"

# 加载 v2ray 脚本
load_v2ray_script() {
    # 模拟 init.sh 中的环境变量
    export IS_CORE=v2ray
    export IS_CORE_DIR=/etc/v2ray
    export IS_CORE_BIN=$IS_CORE_DIR/bin/v2ray
    export IS_CONF_DIR=$IS_CORE_DIR/conf
    export IS_SH_DIR="$SH_DIR"
    export IS_CONFIG_JSON=$IS_CORE_DIR/config.json
    export IS_CADDY_DIR=/etc/caddy
    export IS_CADDY_CONF=$IS_CADDY_DIR/WangYan-Good
    export IS_NGINX_DIR=/etc/nginx
    export IS_NGINX_CONF=$IS_NGINX_DIR/v2ray
    
    # 加载核心脚本
    source "$IS_SH_DIR/src/init.sh"
}

# 清理测试环境
cleanup_test_env() {
    rm -rf /tmp/v2ray_test_*
}

# 创建临时测试目录
setup_test_dirs() {
    export TEST_TMP_DIR="/tmp/v2ray_test_$$"
    mkdir -p "$TEST_TMP_DIR"/{conf,bin,sh/src,log}
    
    # 临时覆盖路径变量
    export IS_CORE_DIR="$TEST_TMP_DIR"
    export IS_CONF_DIR="$TEST_TMP_DIR/conf"
    export IS_LOG_DIR="$TEST_TMP_DIR/log"
}

# 模拟 wget 命令
mock_wget() {
    echo "127.0.0.1"
}

# 模拟 systemctl 命令
mock_systemctl() {
    case "$1" in
        start|stop|restart|enable|disable)
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

# 模拟 netstat 命令
mock_netstat() {
    echo "tcp 0 0 0.0.0.0:22 0.0.0.0:* LISTEN 1234/sshd"
}

# 模拟 ss 命令
mock_ss() {
    echo "LISTEN 0 128 0.0.0.0:22 0.0.0.0:* users:((\"sshd\",pid=1234,fd=3))"
}
