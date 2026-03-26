#!/bin/bash
# V2Ray 批量模式功能验证脚本
# V2Ray Phase 9 - 验证 V2RAY_NON_INTERACTIVE 环境变量是否正确工作

set -e

# 颜色输出
RED='\e[31m'
GREEN='\e[92m'
YELLOW='\e[93m'
BLUE='\e[94m'
NONE='\e[0m'

# 统计变量
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NONE} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NONE} $1"; }
log_error() { echo -e "${RED}[FAIL]${NONE} $1"; }
log_test() { echo -e "${YELLOW}[TEST]${NONE} $1"; }

# 主测试流程
main() {
    log_info "=========================================="
    log_info "V2Ray 批量模式功能验证"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "=========================================="

    cd /home/node/.openclaw/v2ray

    # 测试 1: 验证 pause() 函数在批量模式下跳过
    log_test "测试 1: pause() 函数批量模式支持"
    ((TESTS_TOTAL++))
    if (
        export V2RAY_NON_INTERACTIVE=1
        source src/core.sh
        # 调用 pause 函数，应该在批量模式下立即返回
        pause
        # 如果执行到这里，说明 pause 正确跳过了
        exit 0
    ); then
        ((TESTS_PASSED++))
        log_success "pause() 函数正确支持批量模式"
    else
        ((TESTS_FAILED++))
        log_error "pause() 函数批量模式支持失败"
    fi

    # 测试 2: 验证 ask set_protocol 在批量模式下使用默认值
    log_test "测试 2: ask set_protocol 批量模式支持"
    ((TESTS_TOTAL++))
    if (
        export V2RAY_NON_INTERACTIVE=1
        source src/core.sh
        # 设置默认协议
        export IS_DEFAULT_ARG="VMess-WS-TLS"
        export IS_ASK_SET=""
        # 调用 ask 函数
        ask set_protocol
        # 验证是否使用了默认值
        [[ "$IS_NEW_PROTOCOL" == "VMess-WS-TLS" ]]
    ); then
        ((TESTS_PASSED++))
        log_success "ask set_protocol 正确使用默认值"
    else
        ((TESTS_FAILED++))
        log_error "ask set_protocol 批量模式支持失败"
    fi

    # 测试 3: 验证 ask set_header_type 在批量模式下使用默认值
    log_test "测试 3: ask set_header_type 批量模式支持"
    ((TESTS_TOTAL++))
    if (
        export V2RAY_NON_INTERACTIVE=1
        source src/core.sh
        # 设置默认 header type
        export IS_DEFAULT_ARG="none"
        export HEADER_TYPE=""
        export IS_ASK_SET="header_type"
        # 调用 ask 函数
        ask set_header_type
        # 验证是否使用了默认值
        [[ "$HEADER_TYPE" == "none" ]]
    ); then
        ((TESTS_PASSED++))
        log_success "ask set_header_type 正确使用默认值"
    else
        ((TESTS_FAILED++))
        log_error "ask set_header_type 批量模式支持失败"
    fi

    # 测试 4: 验证 ask set_ss_method 在批量模式下使用默认值
    log_test "测试 4: ask set_ss_method 批量模式支持"
    ((TESTS_TOTAL++))
    if (
        export V2RAY_NON_INTERACTIVE=1
        source src/core.sh
        # 设置默认加密方式
        export IS_DEFAULT_ARG="aes-256-gcm"
        export SS_METHOD=""
        export IS_ASK_SET="SS_METHOD"
        # 调用 ask 函数
        ask set_ss_method
        # 验证是否使用了默认值
        [[ "$SS_METHOD" == "aes-256-gcm" ]]
    ); then
        ((TESTS_PASSED++))
        log_success "ask set_ss_method 正确使用默认值"
    else
        ((TESTS_FAILED++))
        log_error "ask set_ss_method 批量模式支持失败"
    fi

    # 测试 5: 验证 ask string 在批量模式下跳过交互
    log_test "测试 5: ask string 批量模式支持"
    ((TESTS_TOTAL++))
    if (
        export V2RAY_NON_INTERACTIVE=1
        source src/core.sh
        # 设置测试变量
        export TEST_VAR="test-value"
        # 调用 ask string，应该跳过交互
        ask string TEST_VAR "请输入测试值:"
        # 验证变量没有被覆盖
        [[ "$TEST_VAR" == "test-value" ]]
    ); then
        ((TESTS_PASSED++))
        log_success "ask string 正确跳过交互"
    else
        ((TESTS_FAILED++))
        log_error "ask string 批量模式支持失败"
    fi

    # 测试 6: 验证 ask mainmenu 在批量模式下正确退出
    log_test "测试 6: ask mainmenu 批量模式支持"
    ((TESTS_TOTAL++))
    if (
        export V2RAY_NON_INTERACTIVE=1
        source src/core.sh
        # 设置 IS_MAIN_START 来避免加载 V2Ray 核心版本检测
        export IS_MAIN_START=1
        # 调用 ask mainmenu，应该在批量模式下返回而不退出
        # 由于会执行 exit 0，我们需要在子 shell 中检查退出码
        ask mainmenu &>/dev/null
    ); then
        ((TESTS_FAILED++))
        log_error "ask mainmenu 应该在批量模式下退出但未退出"
    else
        ((TESTS_PASSED++))
        log_success "ask mainmenu 正确退出（exit 0）"
    fi

    # 测试 7: 验证 IS_GEN 模式下的配置生成（不保存文件）
    log_test "测试 7: IS_GEN 模式配置生成"
    ((TESTS_TOTAL++))
    if (
        export V2RAY_NON_INTERACTIVE=1
        export IS_GEN=1
        source src/core.sh
        # 设置 Trojan-H2-TLS 配置
        IS_PROTOCOL='trojan'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        TROJAN_PASSWORD='test-batch-mode'
        NET='h2'
        H2_PATH='/batch-h2-path'
        H2_HOST='proxy.yourdie.com'
        # 创建 server 配置（IS_GEN 模式下不会保存文件）
        create server Trojan-H2-TLS &>/dev/null
    ); then
        ((TESTS_PASSED++))
        log_success "IS_GEN 模式配置生成成功"
    else
        ((TESTS_FAILED++))
        log_error "IS_GEN 模式配置生成失败"
    fi

    # 测试 8: 验证交互模式下 ask 函数仍然正常工作
    log_test "测试 8: 交互模式兼容性验证"
    ((TESTS_TOTAL++))
    if (
        # 不设置 V2RAY_NON_INTERACTIVE，使用交互模式
        source src/core.sh
        # 设置默认值
        export IS_DEFAULT_ARG="none"
        export HEADER_TYPE=""
        export IS_ASK_SET="header_type"
        # 由于是交互模式，ask 会尝试读取用户输入
        # 我们通过设置 IS_DEFAULT_ARG 来模拟用户输入空值
        # 这会在交互模式下使用默认值
        # 注意：这个测试只在 IS_DEFAULT_ARG 存在时通过
        ask set_header_type &>/dev/null || true
        # 检查是否使用了默认值
        [[ "$HEADER_TYPE" == "none" ]]
    ); then
        ((TESTS_PASSED++))
        log_success "交互模式兼容性验证通过"
    else
        ((TESTS_FAILED++))
        log_error "交互模式兼容性验证失败"
    fi

    # 测试总结
    log_info ""
    log_info "=========================================="
    log_info "测试总结"
    log_info "=========================================="
    log_info "总测试数: $TESTS_TOTAL"
    log_info "通过: $TESTS_PASSED"
    log_info "失败: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "✓ 所有测试通过！批量模式功能正常。"
        exit 0
    else
        log_error "✗ 部分测试失败！请检查批量模式实现。"
        exit 1
    fi
}

# 运行主测试
main