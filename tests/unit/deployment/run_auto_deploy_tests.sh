#!/bin/bash
# 运行单元测试的简化脚本
# 不依赖 bats，而是使用 bash 测试框架

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

# ========================================
# BATS 简化实现
# ========================================

# 简单的 assertEquals 实现
assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    if [[ "$expected" != "$actual" ]]; then
        log_error "断言失败: $message"
        log_error "  期望: $expected"
        log_error "  实际: $actual"
        return 1
    fi
    return 0
}

# 简单的 assertTrue 实现
assert_true() {
    local condition="$1"
    local message="${2:-}"
    
    if [[ "$condition" != "0" ]]; then
        log_error "断言失败: $message (条件为假)"
        return 1
    fi
    return 0
}

# 简单的 assertFalse 实现
assert_false() {
    local condition="$1"
    local message="${2:-}"
    
    if [[ "$condition" == "0" ]]; then
        log_error "断言失败: $message (条件为真)"
        return 1
    fi
    return 0
}

# 简单的 assert_not_empty 实现
assert_not_empty() {
    local value="$1"
    local message="${2:-}"
    
    if [[ -z "$value" ]]; then
        log_error "断言失败: $message (值为空)"
        return 1
    fi
    return 0
}

# ========================================
# 测试函数
# ========================================

test_auto_deploy_exists() {
    local script_file="/home/node/.openclaw/v2ray/scripts/v2ray-vps-auto-deploy.sh"
    
    log_test "auto_deploy_vps_architecture - 函数存在"
    ((TESTS_TOTAL++))
    
    if grep -q "auto_deploy_vps_architecture()" "$script_file"; then
        log_success "auto_deploy_vps_architecture() 函数存在"
        ((TESTS_PASSED++))
    else
        log_error "auto_deploy_vps_architecture() 函数不存在"
        ((TESTS_FAILED++))
    fi
}

test_cleanup_exists() {
    local script_file="/home/node/.openclaw/v2ray/scripts/v2ray-vps-auto-deploy.sh"
    
    log_test "cleanup_vps_architecture - 函数存在"
    ((TESTS_TOTAL++))
    
    if grep -q "cleanup_vps_architecture()" "$script_file"; then
        log_success "cleanup_vps_architecture() 函数存在"
        ((TESTS_PASSED++))
    else
        log_error "cleanup_vps_architecture() 函数不存在"
        ((TESTS_FAILED++))
    fi
}

test_core_function_exists() {
    local core_file="/home/node/.openclaw/v2ray/src/core.sh"
    
    log_test "core.sh - 函数集成"
    ((TESTS_TOTAL++))
    
    if grep -q "auto_deploy_vps_architecture()" "$core_file"; then
        log_success "auto_deploy_vps_architecture() 在 core.sh 中"
        ((TESTS_PASSED++))
    else
        log_error "auto_deploy_vps_architecture() 不在 core.sh 中"
        ((TESTS_FAILED++))
    fi
    
    ((TESTS_TOTAL++))
    if grep -q "cleanup_vps_architecture()" "$core_file"; then
        log_success "cleanup_vps_architecture() 在 core.sh 中"
        ((TESTS_PASSED++))
    else
        log_error "cleanup_vps_architecture() 不在 core.sh 中"
        ((TESTS_FAILED++))
    fi
}

test_create_integration() {
    local core_file="/home/node/.openclaw/v2ray/src/core.sh"
    
    log_test "create() - 集成 auto_deploy_vps_architecture"
    ((TESTS_TOTAL++))
    
    # 检查 create() 函数中是否调用了 auto_deploy_vps_architecture
    # 使用更长的行数范围来匹配整个函数
    if grep -A 150 "create() {" "$core_file" | grep -q "auto_deploy_vps_architecture"; then
        log_success "create() 集成 auto_deploy_vps_architecture"
        ((TESTS_PASSED++))
    else
        log_error "create() 未集成 auto_deploy_vps_architecture"
        ((TESTS_FAILED++))
    fi
}

test_change_integration() {
    local core_file="/home/node/.openclaw/v2ray/src/core.sh"
    
    log_test "change() - 集成 auto_deploy_vps_architecture"
    ((TESTS_TOTAL++))
    
    # 检查 change() 函数中是否调用了 auto_deploy_vps_architecture
    if grep -A 100 "^change() {" "$core_file" | grep -q "auto_deploy_vps_architecture"; then
        log_success "change() 集成 auto_deploy_vps_architecture"
        ((TESTS_PASSED++))
    else
        log_error "change() 未集成 auto_deploy_vps_architecture"
        ((TESTS_FAILED++))
    fi
}

test_del_integration() {
    local core_file="/home/node/.openclaw/v2ray/src/core.sh"
    
    log_test "del() - 集成 cleanup_vps_architecture"
    ((TESTS_TOTAL++))
    
    # 检查 del() 函数中是否调用了 cleanup_vps_architecture
    if grep -A 50 "^del() {" "$core_file" | grep -q "cleanup_vps_architecture"; then
        log_success "del() 集成 cleanup_vps_architecture"
        ((TESTS_PASSED++))
    else
        log_error "del() 未集成 cleanup_vps_architecture"
        ((TESTS_FAILED++))
    fi
}

test_script_syntax() {
    local script_file="/home/node/.openclaw/v2ray/scripts/v2ray-vps-auto-deploy.sh"
    local core_file="/home/node/.openclaw/v2ray/src/core.sh"
    
    log_test "脚本语法验证"
    ((TESTS_TOTAL++))
    
    if bash -n "$script_file" 2>&1; then
        log_success "auto_deploy 脚本语法正确"
        ((TESTS_PASSED++))
    else
        log_error "auto_deploy 脚本语法错误"
        ((TESTS_FAILED++))
    fi
    
    ((TESTS_TOTAL++))
    if bash -n "$core_file" 2>&1; then
        log_success "core.sh 语法正确"
        ((TESTS_PASSED++))
    else
        log_error "core.sh 语法错误"
        ((TESTS_FAILED++))
    fi
}

test_helper_exists() {
    local helper_file="/home/node/.openclaw/v2ray/tests/helpers/test_helper.sh"
    
    log_test "辅助脚本存在"
    ((TESTS_TOTAL++))
    
    if [[ -f "$helper_file" ]]; then
        log_success "test_helper.sh 存在"
        ((TESTS_PASSED++))
    else
        log_error "test_helper.sh 不存在"
        ((TESTS_FAILED++))
    fi
}

# ========================================
# 主测试流程
# ========================================

main() {
    log_info "=========================================="
    log_info "V2Ray VPS 架构自动部署单元测试"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "=========================================="
    
    cd /home/node/.openclaw/v2ray
    
    # 检查必需工具
    if [[ ! -x /tmp/jq ]]; then
        log_error "/tmp/jq 不存在，请先安装 jq"
        log_error "✗ 部分测试失败！"
        exit 1
    fi
    
    # 运行测试
    test_auto_deploy_exists
    test_cleanup_exists
    test_core_function_exists
    test_create_integration
    test_change_integration
    test_del_integration
    test_script_syntax
    test_helper_exists
    
    # 显示测试结果
    log_info ""
    log_info "=========================================="
    log_info "测试总结"
    log_info "=========================================="
    log_info "总测试数: $TESTS_TOTAL"
    log_info "通过: $TESTS_PASSED"
    log_info "失败: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "✓ 所有测试通过！"
        exit 0
    else
        log_error "✗ 部分测试失败！"
        exit 1
    fi
}

# 运行主测试
main "$@"
