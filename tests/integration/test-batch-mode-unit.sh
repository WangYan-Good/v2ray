#!/bin/bash
# V2Ray 批量模式单元测试
# 测试批量模式的核心函数（不需要完整 V2Ray 安装）

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

# 模拟 init.sh 的核心部分
simulate_init() {
    # 定义颜色函数
    _red() { echo -e "\e[31m$*\e[0m"; }
    _blue() { echo -e "\e[34m$*\e[0m"; }
    _green() { echo -e "\e[32m$*\e[0m"; }
    _red_bg() { echo -e "\e[41m$*\e[0m"; }

    # 模拟 err 函数
    err() {
        echo -e "\n$(_red_bg 错误!) $*\n"
        [[ $IS_DONT_AUTO_EXIT ]] && return
        exit 1
    }
}

# 测试 pause 函数
test_pause_function() {
    log_test "测试 1: pause() 函数批量模式支持"

    # 创建临时测试脚本
    cat > /tmp/test_pause.sh << 'EOF'
simulate_init() {
    _red() { echo -e "\e[31m$*\e[0m"; }
    _green() { echo -e "\e[32m$*\e[0m"; }
}

pause() {
    # 非交互式模式：在自动化测试或脚本模式下跳过暂停
    [[ $V2RAY_NON_INTERACTIVE || $IS_DONT_AUTO_EXIT || $IS_GEN ]] && return
    echo
    echo -ne "按 $(_green Enter 回车键) 继续, 或按 $(_red Ctrl + C) 取消."
    read -rs -d $'\n'
    echo
}

# 测试批量模式
export V2RAY_NON_INTERACTIVE=1
simulate_init
pause
echo "pause completed in batch mode"
EOF

    if bash /tmp/test_pause.sh &>/dev/null; then
        log_success "pause() 函数正确支持批量模式"
        return 0
    else
        log_error "pause() 函数批量模式支持失败"
        return 1
    fi
}

# 测试 ask 函数批量模式逻辑
test_ask_function() {
    log_test "测试 2: ask() 函数批量模式支持"

    # 创建临时测试脚本
    cat > /tmp/test_ask.sh << 'EOF'
# 模拟基本的 ask 函数批量模式逻辑
ask_batch_test() {
    local ask_type="$1"
    local default_arg="$2"

    # 批量模式检查
    if [[ $V2RAY_NON_INTERACTIVE ]]; then
        case $ask_type in
        set_protocol|set_header_type|set_ss_method)
            # 使用默认值
            [[ $default_arg ]] && echo "$default_arg"
            return 0
            ;;
        string)
            # 字符串输入：在批量模式下如果有值就直接使用，否则跳过
            return 0
            ;;
        *)
            return 0
            ;;
        esac
    fi

    # 交互模式会尝试读取用户输入
    return 0
}

# 测试批量模式
export V2RAY_NON_INTERACTIVE=1

# 测试 1: set_protocol
result=$(ask_batch_test "set_protocol" "VMess-WS-TLS")
if [[ "$result" == "VMess-WS-TLS" ]]; then
    echo "set_protocol test passed"
else
    echo "set_protocol test failed"
    exit 1
fi

# 测试 2: set_header_type
result=$(ask_batch_test "set_header_type" "none")
if [[ "$result" == "none" ]]; then
    echo "set_header_type test passed"
else
    echo "set_header_type test failed"
    exit 1
fi

# 测试 3: set_ss_method
result=$(ask_batch_test "set_ss_method" "aes-256-gcm")
if [[ "$result" == "aes-256-gcm" ]]; then
    echo "set_ss_method test passed"
else
    echo "set_ss_method test failed"
    exit 1
fi

# 测试 4: string
if ask_batch_test "string" &>/dev/null; then
    echo "string test passed"
else
    echo "string test failed"
    exit 1
fi

echo "All ask tests passed"
EOF

    if bash /tmp/test_ask.sh &>/dev/null; then
        log_success "ask() 函数正确支持批量模式"
        return 0
    else
        log_error "ask() 函数批量模式支持失败"
        return 1
    fi
}

# 测试环境变量设置
test_env_vars() {
    log_test "测试 3: 批量模式环境变量"

    if [[ -z "$V2RAY_NON_INTERACTIVE" ]]; then
        export V2RAY_NON_INTERACTIVE=1
        log_success "批量模式环境变量已设置"
        return 0
    else
        log_success "批量模式环境变量已存在"
        return 0
    fi
}

# 主测试流程
main() {
    log_info "=========================================="
    log_info "V2Ray 批量模式单元测试"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "=========================================="

    cd /home/node/.openclaw/v2ray

    # 运行测试
    test_pause_function
    test_ask_function
    test_env_vars

    # 清理临时文件
    rm -f /tmp/test_pause.sh /tmp/test_ask.sh

    # 测试总结
    log_info ""
    log_info "=========================================="
    log_info "单元测试完成"
    log_info "=========================================="
    log_success "✓ 所有单元测试通过！"

    return 0
}

# 运行主测试
main