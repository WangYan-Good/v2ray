#!/usr/bin/env bash
#
# 测试辅助加载脚本
#

# 设置基本环境变量
export IS_CORE=v2ray
export IS_CORE_DIR=/home/node/.openclaw/v2ray
export IS_SH_DIR="/home/node/.openclaw/v2ray"
export IS_CONF_DIR=$IS_CORE_DIR/conf
export IS_LOG_DIR=/var/log/$IS_CORE
export IS_CADDY_DIR=/etc/caddy
export IS_CADDY_CONF=$IS_CADDY_DIR/WangYan-Good
export IS_NGINX_DIR=/etc/nginx
export IS_NGINX_CONF=$IS_NGINX_DIR/v2ray
export AUTHOR=WangYan-Good

# 定义颜色和消息变量（从 init.sh 复制）
export IS_ERR="\e[31m错误!\e[0m"
export IS_WARN="\e[33m警告!\e[0m"
export IS_INFO="\e[32m信息!\e[0m"
export IS_INPUT="\e[36m请输入\e[0m"
export IS_OPT="\e[36m请选择\e[0m"

# 定义 err 和 warn 函数
err() {
    echo -e "\n$IS_ERR $*\n"
    [[ $IS_DONT_AUTO_EXIT ]] && return
    exit 1
}

warn() {
    echo -e "\n$IS_WARN $*\n"
}

msg() {
    echo -e "$*"
}

# Mock is_port_used 函数，避免依赖 netstat/ss
is_port_used() {
    # 测试环境中假设端口都可用
    return 1
}

# 加载 core.sh 中的函数（不执行 main）
load_core_functions() {
    # 设置标志跳过端口检测
    export IS_CANT_TEST_PORT=1
    # 只加载函数定义，不执行脚本
    source "$IS_SH_DIR/src/core.sh" 2>/dev/null || source "/home/node/.openclaw/v2ray/src/core.sh"
}
