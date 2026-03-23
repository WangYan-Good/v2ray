#!/usr/bin/env bats
#
# log.sh 日志功能单元测试
#

setup() {
    source "$BATS_TEST_DIRNAME/../helpers/test_helper.sh"
    
    # 创建临时测试目录
    export TEST_TMP_DIR="/tmp/v2ray_log_test_$$"
    mkdir -p "$TEST_TMP_DIR/log"
    
    # 临时覆盖日志目录
    export IS_LOG_DIR="$TEST_TMP_DIR/log"
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

@test "log - 应该输出消息" {
    load_core_functions
    source "$IS_SH_DIR/src/log.sh"
    
    run log "test log message"
    [[ "$output" == "test log message" ]]
}

@test "log_info - 应该输出带时间戳的信息日志" {
    load_core_functions
    source "$IS_SH_DIR/src/log.sh"
    
    run log_info "test info message"
    [[ "$output" =~ \[INFO\] ]]
    [[ "$output" =~ "test info message" ]]
    [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]
}

@test "log_warn - 应该输出警告日志" {
    source "$IS_SH_DIR/src/log.sh"
    
    # log_warn outputs to stderr, redirect to stdout for capture
    run bash -c 'source /home/node/.openclaw/v2ray/src/log.sh; log_warn "test warn message" 2>&1'
    [[ "$output" =~ \[WARN\] ]]
    [[ "$output" =~ "test warn message" ]]
}

@test "log_error - 应该输出错误日志" {
    source "$IS_SH_DIR/src/log.sh"
    
    # log_error outputs to stderr, redirect to stdout for capture
    run bash -c 'source /home/node/.openclaw/v2ray/src/log.sh; log_error "test error message" 2>&1'
    [[ "$output" =~ \[ERROR\] ]]
    [[ "$output" =~ "test error message" ]]
}
