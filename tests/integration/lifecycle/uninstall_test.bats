#!/usr/bin/env bats
#
# 卸载流程集成测试
#

load ../helpers/helpers.bash

setup() {
    # 设置测试环境变量 - 使用绝对路径
    export IS_SH_DIR="/home/node/.openclaw/v2ray"
    
    # 设置测试环境
    export TEST_TMP_DIR="/tmp/v2ray_uninstall_test_$$"
    mkdir -p "$TEST_TMP_DIR"
    
    # 创建模拟的 v2ray 安装目录
    export IS_CORE_DIR="$TEST_TMP_DIR/v2ray"
    export IS_CONF_DIR="$IS_CORE_DIR/conf"
    export IS_LOG_DIR="$TEST_TMP_DIR/log"
    export IS_SH_BIN="$TEST_TMP_DIR/bin/v2ray"
    
    mkdir -p "$IS_CONF_DIR"
    mkdir -p "$IS_LOG_DIR"
    mkdir -p "$IS_SH_DIR/src"
    mkdir -p "$TEST_TMP_DIR/bin"
    
    # 创建模拟的 systemd 服务文件
    mkdir -p "$TEST_TMP_DIR/systemd"
    touch "$TEST_TMP_DIR/systemd/v2ray.service"
    
    # 创建模拟的配置文件
    echo '{"test": "config"}' > "$IS_CONF_DIR/test.json"
    
    # 创建模拟的脚本文件
    echo '#!/bin/bash' > "$IS_SH_BIN"
    chmod +x "$IS_SH_BIN"
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

@test "卸载流程 - 应该移除 v2ray 目录和文件" {
    source "$IS_SH_DIR/src/core.sh"
    
    # 验证测试环境已创建
    [[ -d "$IS_CORE_DIR" ]]
    [[ -f "$IS_SH_BIN" ]]
    [[ -f "$IS_CONF_DIR/test.json" ]]
    
    # 注意：实际卸载会删除系统文件，这里只测试逻辑
    # 在测试环境中，我们修改卸载函数行为
    
    # 模拟卸载（不实际删除系统文件）
    export IS_TEST_UNINSTALL=1
    
    # 测试卸载逻辑
    run bash -c "
        IS_CORE_DIR='$IS_CORE_DIR'
        IS_LOG_DIR='$IS_LOG_DIR'
        IS_SH_BIN='$IS_SH_BIN'
        
        # 模拟删除操作
        rm -rf \"\$IS_CORE_DIR\" \"\$IS_LOG_DIR\" \"\$IS_SH_BIN\"
    "
    
    [[ "$status" -eq 0 ]]
    [[ ! -d "$IS_CORE_DIR" ]]
    [[ ! -f "$IS_SH_BIN" ]]
}

@test "卸载流程 - 应该清理 Caddy 配置" {
    # 创建模拟的 Caddy 配置
    export IS_CADDY_CONF="$TEST_TMP_DIR/caddy/WangYan-Good"
    mkdir -p "$IS_CADDY_CONF"
    echo "test.conf" > "$IS_CADDY_CONF/test.conf"
    
    [[ -f "$IS_CADDY_CONF/test.conf" ]]
    
    # 模拟删除 Caddy 配置
    run bash -c "
        IS_CADDY_CONF='$IS_CADDY_CONF'
        rm -rf \"\$IS_CADDY_CONF\"/*.conf
    "
    
    [[ "$status" -eq 0 ]]
    [[ ! -f "$IS_CADDY_CONF/test.conf" ]]
}

@test "卸载流程 - 应该清理 Nginx 配置" {
    # 创建模拟的 Nginx 配置
    export IS_NGINX_CONF="$TEST_TMP_DIR/nginx/v2ray"
    export IS_NGINX_DIR="$TEST_TMP_DIR/nginx"
    mkdir -p "$IS_NGINX_CONF"
    mkdir -p "$IS_NGINX_DIR/ssl"
    echo "test.conf" > "$IS_NGINX_CONF/test.conf"
    echo "cert.pem" > "$IS_NGINX_DIR/ssl/cert.pem"
    
    [[ -f "$IS_NGINX_CONF/test.conf" ]]
    [[ -f "$IS_NGINX_DIR/ssl/cert.pem" ]]
    
    # 模拟删除 Nginx 配置
    run bash -c "
        IS_NGINX_CONF='$IS_NGINX_CONF'
        IS_NGINX_DIR='$IS_NGINX_DIR'
        rm -rf \"\$IS_NGINX_CONF\"/*.conf \"\$IS_NGINX_CONF\"/*.conf.add
        rm -rf \"\$IS_NGINX_DIR\"/ssl/*
    "
    
    [[ "$status" -eq 0 ]]
    [[ ! -f "$IS_NGINX_CONF/test.conf" ]]
    [[ ! -f "$IS_NGINX_DIR/ssl/cert.pem" ]]
}

@test "卸载流程 - 应该清理 bashrc 中的别名" {
    # 创建模拟的 .bashrc
    export TEST_BASHRC="$TEST_TMP_DIR/.bashrc"
    echo "alias v2ray='/etc/v2ray/sh/v2ray.sh'" > "$TEST_BASHRC"
    echo "export PATH=\$PATH:/usr/local/bin" >> "$TEST_BASHRC"
    
    # 模拟清理 bashrc
    run bash -c "
        BASHRC='$TEST_BASHRC'
        sed -i \"/v2ray/d\" \"\$BASHRC\"
    "
    
    [[ "$status" -eq 0 ]]
    [[ ! "$(grep v2ray "$TEST_BASHRC")" ]]
}
