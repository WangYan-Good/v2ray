#!/bin/bash
# test_improvements.sh - Phase 1 代码改进测试脚本

set -e

RED='\e[31m'
GREEN='\e[92m'
YELLOW='\e[33m'
NONE='\e[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo -e "${GREEN}[PASS]${NONE} $1"
    ((PASS_COUNT++))
}

fail() {
    echo -e "${RED}[FAIL]${NONE} $1"
    ((FAIL_COUNT++))
}

info() {
    echo -e "${YELLOW}[INFO]${NONE} $1"
}

##
## 测试 1: 错误码定义
##
test_error_codes() {
    info "测试错误码定义..."
    
    # shellcheck source=/dev/null
    . src/error.sh
    
    if [[ $ERR_SUCCESS -eq 0 && $ERR_GENERAL -eq 1 && $ERR_INVALID_ARGS -eq 2 ]]; then
        pass "错误码定义正确"
    else
        fail "错误码定义错误"
    fi
}

##
## 测试 2: validate_port 函数
##
test_validate_port() {
    info "测试端口验证函数..."
    
    # shellcheck source=/dev/null
    . src/error.sh
    
    # 测试有效端口 (使用子 shell 避免 exit)
    if (IS_DONT_AUTO_EXIT=1; validate_port 80 2>/dev/null); then
        pass "有效端口验证通过 (80)"
    else
        fail "有效端口验证失败 (80)"
    fi
    
    if (IS_DONT_AUTO_EXIT=1; validate_port 65535 2>/dev/null); then
        pass "有效端口验证通过 (65535)"
    else
        fail "有效端口验证失败 (65535)"
    fi
    
    # 测试无效端口
    if ! (IS_DONT_AUTO_EXIT=1; validate_port 0 2>/dev/null); then
        pass "无效端口验证通过 (0)"
    else
        fail "无效端口验证失败 (0)"
    fi
    
    if ! (IS_DONT_AUTO_EXIT=1; validate_port 65536 2>/dev/null); then
        pass "无效端口验证通过 (65536)"
    else
        fail "无效端口验证失败 (65536)"
    fi
    
    if ! (IS_DONT_AUTO_EXIT=1; validate_port "abc" 2>/dev/null); then
        pass "无效端口验证通过 (abc)"
    else
        fail "无效端口验证失败 (abc)"
    fi
}

##
## 测试 3: validate_uuid 函数
##
test_validate_uuid() {
    info "测试 UUID 验证函数..."
    
    # shellcheck source=/dev/null
    . src/error.sh
    
    # 测试有效 UUID
    if (IS_DONT_AUTO_EXIT=1; validate_uuid "550e8400-e29b-41d4-a716-446655440000" 2>/dev/null); then
        pass "有效 UUID 验证通过"
    else
        fail "有效 UUID 验证失败"
    fi
    
    # 测试无效 UUID
    if ! (IS_DONT_AUTO_EXIT=1; validate_uuid "invalid-uuid" 2>/dev/null); then
        pass "无效 UUID 验证通过"
    else
        fail "无效 UUID 验证失败"
    fi
    
    if ! (IS_DONT_AUTO_EXIT=1; validate_uuid "550e8400e29b41d4a716446655440000" 2>/dev/null); then
        pass "无效 UUID 验证通过 (无连字符)"
    else
        fail "无效 UUID 验证失败 (无连字符)"
    fi
}

##
## 测试 4: validate_domain 函数
##
test_validate_domain() {
    info "测试域名验证函数..."
    
    # shellcheck source=/dev/null
    . src/error.sh
    
    # 测试有效域名
    if (IS_DONT_AUTO_EXIT=1; validate_domain "example.com" 2>/dev/null); then
        pass "有效域名验证通过 (example.com)"
    else
        fail "有效域名验证失败 (example.com)"
    fi
    
    if (IS_DONT_AUTO_EXIT=1; validate_domain "sub.example.com" 2>/dev/null); then
        pass "有效域名验证通过 (sub.example.com)"
    else
        fail "有效域名验证失败 (sub.example.com)"
    fi
    
    # 测试无效域名
    if ! (IS_DONT_AUTO_EXIT=1; validate_domain "invalid_domain" 2>/dev/null); then
        pass "无效域名验证通过"
    else
        fail "无效域名验证失败"
    fi
}

##
## 测试 5: 日志系统
##
test_log_system() {
    info "测试日志系统..."
    
    # shellcheck source=/dev/null
    . src/log.sh
    
    # 测试日志函数是否存在
    if declare -f log_info &>/dev/null; then
        pass "log_info 函数已定义"
    else
        fail "log_info 函数未定义"
    fi
    
    if declare -f log_warn &>/dev/null; then
        pass "log_warn 函数已定义"
    else
        fail "log_warn 函数未定义"
    fi
    
    if declare -f log_error &>/dev/null; then
        pass "log_error 函数已定义"
    else
        fail "log_error 函数未定义"
    fi
    
    if declare -f log_debug &>/dev/null; then
        pass "log_debug 函数已定义"
    else
        fail "log_debug 函数未定义"
    fi
}

##
## 测试 6: ShellCheck 检查
##
test_shellcheck() {
    info "运行 ShellCheck 检查..."
    
    local warning_count=0
    
    if command -v shellcheck &>/dev/null; then
        warning_count=$(shellcheck install.sh src/*.sh 2>&1 | grep -c "SC2[0-9][0-9][0-9]" || echo "0")
        
        if [[ $warning_count -lt 50 ]]; then
            pass "ShellCheck 警告数量可接受 ($warning_count 个严重警告)"
        else
            fail "ShellCheck 警告过多 ($warning_count 个严重警告)"
        fi
    else
        info "ShellCheck 未安装，跳过检查"
    fi
}

##
## 测试 7: 错误处理函数
##
test_error_handling() {
    info "测试错误处理函数..."
    
    # shellcheck source=/dev/null
    . src/error.sh
    
    # 测试 error_exit 函数
    if declare -f error_exit &>/dev/null; then
        pass "error_exit 函数已定义"
    else
        fail "error_exit 函数未定义"
    fi
    
    # 测试 check_command 函数
    if declare -f check_command &>/dev/null; then
        pass "check_command 函数已定义"
    else
        fail "check_command 函数未定义"
    fi
}

##
## 主测试函数
##
main() {
    echo "======================================"
    echo "Phase 1 代码改进测试"
    echo "======================================"
    echo
    
    test_error_codes
    test_validate_port
    test_validate_uuid
    test_validate_domain
    test_log_system
    test_error_handling
    test_shellcheck
    
    echo
    echo "======================================"
    echo "测试结果汇总"
    echo "======================================"
    echo -e "${GREEN}通过：$PASS_COUNT${NONE}"
    echo -e "${RED}失败：$FAIL_COUNT${NONE}"
    echo
    
    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "${GREEN}所有测试通过！${NONE}"
        exit 0
    else
        echo -e "${RED}部分测试失败！${NONE}"
        exit 1
    fi
}

# 切换到脚本所在目录
cd "$(dirname "$0")"

main "$@"
