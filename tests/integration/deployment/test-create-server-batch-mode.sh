#!/bin/bash
# 测试 create server 批量模式
# V2Ray Phase 9 - 批量模式测试脚本
#
# 用途: 验证 create server 函数在非交互模式下的批量配置生成能力

set -e

# 导入批量模式环境变量
export V2RAY_NON_INTERACTIVE=1

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

# 测试结果记录
declare -a TEST_RESULTS=()

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NONE} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NONE} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NONE} $1"
}

log_test() {
    echo -e "${YELLOW}[TEST]${NONE} $1"
}

# 测试辅助函数
run_test() {
    local test_name="$1"
    local test_cmd="$2"

    ((TESTS_TOTAL++))
    log_test "测试 $TESTS_TOTAL: $test_name"

    if eval "$test_cmd" 2>&1 | tee -a /tmp/v2ray-batch-test.log; then
        ((TESTS_PASSED++))
        log_success "$test_name - 通过"
        TEST_RESULTS+=("✓ $test_name")
    else
        ((TESTS_FAILED++))
        log_error "$test_name - 失败"
        TEST_RESULTS+=("✗ $test_name")
    fi
}

# 清理函数
cleanup() {
    log_info "清理测试配置文件..."
    rm -f /tmp/v2ray-batch-test.log
}

# 主测试流程
main() {
    log_info "=========================================="
    log_info "V2Ray 批量模式测试开始"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "=========================================="

    # 进入 v2ray 目录
    cd /home/node/.openclaw/v2ray

    # 加载核心脚本
    log_info "加载核心脚本..."
    source src/core.sh

    # 测试 1: Trojan-H2-TLS
    run_test "Trojan-H2-TLS 批量配置生成" "
        IS_PROTOCOL='trojan'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        TROJAN_PASSWORD='test-batch-h2-\$(date +%s)'
        NET='h2'
        H2_PATH='/batch-h2-path'
        H2_HOST='proxy.yourdie.com'
        create server Trojan-H2-TLS
    "

    # 测试 2: Trojan-WS-TLS
    run_test "Trojan-WS-TLS 批量配置生成" "
        IS_PROTOCOL='trojan'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        TROJAN_PASSWORD='test-batch-ws-\$(date +%s)'
        NET='ws'
        WS_PATH='/batch-ws-path'
        WS_HOST='proxy.yourdie.com'
        create server Trojan-WS-TLS
    "

    # 测试 3: Trojan-gRPC-TLS
    run_test "Trojan-gRPC-TLS 批量配置生成" "
        IS_PROTOCOL='trojan'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        TROJAN_PASSWORD='test-batch-grpc-\$(date +%s)'
        NET='grpc'
        GRPC_SERVICE_NAME='batch-grpc-service'
        GRPC_HOST='proxy.yourdie.com'
        create server Trojan-gRPC-TLS
    "

    # 测试 4: VMess-WS-TLS
    run_test "VMess-WS-TLS 批量配置生成" "
        IS_PROTOCOL='vmess'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        UUID='test-batch-vmess-\$(date +%s)'
        NET='ws'
        WS_PATH='/batch-vmess-path'
        WS_HOST='proxy.yourdie.com'
        create server VMess-WS-TLS
    "

    # 测试 5: VMess-H2-TLS
    run_test "VMess-H2-TLS 批量配置生成" "
        IS_PROTOCOL='vmess'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        UUID='test-batch-vmess-h2-\$(date +%s)'
        NET='h2'
        H2_PATH='/batch-vmess-h2-path'
        H2_HOST='proxy.yourdie.com'
        create server VMess-H2-TLS
    "

    # 检查生成的配置文件
    log_info "检查生成的配置文件..."
    log_info "配置目录: /etc/v2ray/configs/"

    if [[ -d /etc/v2ray/configs ]]; then
        log_info "生成的配置文件:"
        ls -lh /etc/v2ray/configs/*.json | tail -5

        log_info "最新配置文件内容验证:"
        latest_config=$(ls -t /etc/v2ray/configs/*.json | head -1)
        if [[ -f "$latest_config" ]]; then
            log_info "配置文件: $latest_config"
            if command -v jq &>/dev/null; then
                jq . "$latest_config" | head -20
            else
                cat "$latest_config" | head -20
            fi
        fi
    else
        log_error "配置目录不存在: /etc/v2ray/configs/"
    fi

    # 测试总结
    log_info "=========================================="
    log_info "测试总结"
    log_info "=========================================="
    log_info "总测试数: $TESTS_TOTAL"
    log_info "通过: $TESTS_PASSED"
    log_info "失败: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "所有测试通过！"
    else
        log_error "部分测试失败！"
    fi

    log_info ""
    log_info "测试结果详情:"
    for result in "${TEST_RESULTS[@]}"; do
        echo "  $result"
    done

    log_info ""
    log_info "=========================================="
    log_info "测试完成"
    log_info "=========================================="
}

# 捕获退出信号
trap cleanup EXIT

# 运行主测试
main