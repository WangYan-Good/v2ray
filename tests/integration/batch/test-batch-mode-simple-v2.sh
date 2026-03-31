#!/bin/bash
# 简化的批量模式测试脚本

set -e

RED='\e[31m'
GREEN='\e[92m'
YELLOW='\e[93m'
BLUE='\e[94m'
NONE='\e[0m'

log_info() { echo -e "${BLUE}[INFO]${NONE} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NONE} $1"; }
log_error() { echo -e "${RED}[FAIL]${NONE} $1"; }
log_test() { echo -e "${YELLOW}[TEST]${NONE} $1"; }

TESTS_PASSED=0
TESTS_FAILED=0

main() {
    log_info "=========================================="
    log_info "V2Ray 批量模式功能验证"
    log_info "=========================================="

    cd /home/node/.openclaw/v2ray

    # 测试 1: pause() 函数
    log_test "测试 1: pause() 函数批量模式支持"
    if (
        export V2RAY_NON_INTERACTIVE=1
        source src/core.sh
        pause 2>&1
    ); then
        ((TESTS_PASSED++))
        log_success "pause() 函数正确支持批量模式"
    else
        ((TESTS_FAILED++))
        log_error "pause() 函数批量模式支持失败"
    fi

    # 测试 2: ask set_protocol
    log_test "测试 2: ask set_protocol 批量模式支持"
    if (
        export V2RAY_NON_INTERACTIVE=1
        source src/core.sh
        export IS_DEFAULT_ARG="VMess-WS-TLS"
        export IS_ASK_SET=""
        ask set_protocol 2>&1
    ); then
        ((TESTS_PASSED++))
        log_success "ask set_protocol 正确使用默认值"
    else
        ((TESTS_FAILED++))
        log_error "ask set_protocol 批量模式支持失败"
    fi

    # 测试 3: ask set_header_type
    log_test "测试 3: ask set_header_type 批量模式支持"
    if (
        export V2RAY_NON_INTERACTIVE=1
        source src/core.sh
        export IS_DEFAULT_ARG="none"
        export HEADER_TYPE=""
        export IS_ASK_SET="header_type"
        ask set_header_type 2>&1
    ); then
        ((TESTS_PASSED++))
        log_success "ask set_header_type 正确使用默认值"
    else
        ((TESTS_FAILED++))
        log_error "ask set_header_type 批量模式支持失败"
    fi

    # 测试 4: ask set_ss_method
    log_test "测试 4: ask set_ss_method 批量模式支持"
    if (
        export V2RAY_NON_INTERACTIVE=1
        source src/core.sh
        export IS_DEFAULT_ARG="aes-256-gcm"
        export SS_METHOD=""
        export IS_ASK_SET="SS_METHOD"
        ask set_ss_method 2>&1
    ); then
        ((TESTS_PASSED++))
        log_success "ask set_ss_method 正确使用默认值"
    else
        ((TESTS_FAILED++))
        log_error "ask set_ss_method 批量模式支持失败"
    fi

    # 测试 5: ask string
    log_test "测试 5: ask string 批量模式支持"
    if (
        export V2RAY_NON_INTERACTIVE=1
        source src/core.sh
        export TEST_VAR="test-value"
        ask string TEST_VAR "请输入测试值:" 2>&1
    ); then
        ((TESTS_PASSED++))
        log_success "ask string 正确跳过交互"
    else
        ((TESTS_FAILED++))
        log_error "ask string 批量模式支持失败"
    fi

    # 测试 6: IS_GEN 模式配置生成
    log_test "测试 6: IS_GEN 模式配置生成"
    if (
        export V2RAY_NON_INTERACTIVE=1
        export IS_GEN=1
        source src/core.sh 2>&1
        IS_PROTOCOL='trojan'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        TROJAN_PASSWORD='test-batch-mode'
        NET='h2'
        H2_PATH='/batch-h2-path'
        H2_HOST='proxy.yourdie.com'
        create server Trojan-H2-TLS 2>&1
    ); then
        ((TESTS_PASSED++))
        log_success "IS_GEN 模式配置生成成功"
    else
        ((TESTS_FAILED++))
        log_error "IS_GEN 模式配置生成失败"
    fi

    # 测试总结
    log_info ""
    log_info "=========================================="
    log_info "测试总结: 通过 $TESTS_PASSED / 失败 $TESTS_FAILED"
    log_info "=========================================="

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "✓ 所有测试通过！"
        exit 0
    else
        log_error "✗ 部分测试失败！"
        exit 1
    fi
}

main