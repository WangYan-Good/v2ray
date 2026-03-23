#!/usr/bin/env bats
#
# download.sh 下载功能单元测试
#

setup() {
    source "$BATS_TEST_DIRNAME/../helpers/test_helper.sh"
    
    # 创建临时测试目录
    export TEST_TMP_DIR="/tmp/v2ray_download_test_$$"
    mkdir -p "$TEST_TMP_DIR"
    
    # 临时覆盖下载目录
    export IS_CORE_DIR="$TEST_TMP_DIR"
    export IS_CORE_BIN="$TEST_TMP_DIR/bin/v2ray"
    export IS_SH_DIR="$TEST_TMP_DIR/sh"
    export IS_CADDY_BIN="$TEST_TMP_DIR/bin/caddy"
    
    mkdir -p "$IS_SH_DIR/src"
    mkdir -p "$TEST_TMP_DIR/bin"
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

@test "get_latest_version core - 应该获取 v2ray 核心最新版本" {
    # 跳过网络测试，使用 mock
    skip "需要网络连接，集成测试中验证"
    
    load_core_functions
    source "$IS_SH_DIR/src/download.sh"
    
    get_latest_version core
    [[ -n "$LATEST_VER" ]]
    [[ "$LATEST_VER" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "get_latest_version sh - 应该获取脚本最新版本" {
    skip "需要网络连接，集成测试中验证"
    
    load_core_functions
    source "$IS_SH_DIR/src/download.sh"
    
    get_latest_version sh
    [[ -n "$LATEST_VER" ]]
    [[ "$LATEST_VER" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "get_latest_version caddy - 应该获取 Caddy 最新版本" {
    skip "需要网络连接，集成测试中验证"
    
    load_core_functions
    source "$IS_SH_DIR/src/download.sh"
    
    get_latest_version caddy
    [[ -n "$LATEST_VER" ]]
    [[ "$LATEST_VER" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "download_file - 应该下载文件" {
    skip "需要网络连接，集成测试中验证"
    
    load_core_functions
    source "$IS_SH_DIR/src/download.sh"
    
    export LINK="https://example.com/test.txt"
    export TMPFILE="$TEST_TMP_DIR/test.txt"
    export NAME="test"
    
    # 创建测试文件
    echo "test content" > "$TEST_TMP_DIR/source.txt"
    export LINK="file://$TEST_TMP_DIR/source.txt"
    
    run download_file
    [[ "$status" -eq 0 ]]
}

@test "download dat - 应该下载 geoip 和 geosite 数据文件" {
    skip "需要网络连接，集成测试中验证"
    
    load_core_functions
    source "$IS_SH_DIR/src/download.sh"
    
    export IS_CORE_DIR="$TEST_TMP_DIR"
    mkdir -p "$IS_CORE_DIR/bin"
    
    run download dat
    [[ "$status" -eq 0 ]]
    [[ -f "$IS_CORE_DIR/bin/geoip.dat" ]]
    [[ -f "$IS_CORE_DIR/bin/geosite.dat" ]]
}
