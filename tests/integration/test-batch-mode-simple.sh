#!/bin/bash
# 简化的批量模式测试脚本（不需要 root 权限）
# V2Ray Phase 9 - 批量模式功能验证

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

# 测试结果记录
declare -a TEST_RESULTS=()

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NONE} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NONE} $1"; }
log_error() { echo -e "${RED}[FAIL]${NONE} $1"; }
log_test() { echo -e "${YELLOW}[TEST]${NONE} $1"; }

# 测试辅助函数
run_test() {
    local test_name="$1"
    local test_cmd="$2"

    ((TESTS_TOTAL++))
    log_test "测试 $TESTS_TOTAL: $test_name"

    # 在子 shell 中运行测试，避免环境变量污染
    if (
        export V2RAY_NON_INTERACTIVE=1
        cd /home/node/.openclaw/v2ray
        # 只设置 IS_GEN=1 来生成 JSON 而不保存文件
        export IS_GEN=1
        eval "$test_cmd" &>/dev/null
    ); then
        ((TESTS_PASSED++))
        log_success "$test_name - 通过"
        TEST_RESULTS+=("✓ $test_name")
    else
        ((TESTS_FAILED++))
        log_error "$test_name - 失败"
        TEST_RESULTS+=("✗ $test_name")
    fi
}

# 主测试流程
main() {
    log_info "=========================================="
    log_info "V2Ray 批量模式功能验证（简化版）"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "=========================================="

    # 进入 v2ray 目录
    cd /home/node/.openclaw/v2ray

    # 测试 1: Trojan-H2-TLS 批量配置生成
    run_test "Trojan-H2-TLS 批量配置生成" "
        source src/core.sh
        IS_PROTOCOL='trojan'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        TROJAN_PASSWORD='test-batch-h2'
        NET='h2'
        H2_PATH='/batch-h2-path'
        H2_HOST='proxy.yourdie.com'
        create server Trojan-H2-TLS
    "

    # 测试 2: Trojan-WS-TLS 批量配置生成
    run_test "Trojan-WS-TLS 批量配置生成" "
        source src/core.sh
        IS_PROTOCOL='trojan'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        TROJAN_PASSWORD='test-batch-ws'
        NET='ws'
        WS_PATH='/batch-ws-path'
        WS_HOST='proxy.yourdie.com'
        create server Trojan-WS-TLS
    "

    # 测试 3: Trojan-gRPC-TLS 批量配置生成
    run_test "Trojan-gRPC-TLS 批量配置生成" "
        source src/core.sh
        IS_PROTOCOL='trojan'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        TROJAN_PASSWORD='test-batch-grpc'
        NET='grpc'
        GRPC_SERVICE_NAME='batch-grpc-service'
        GRPC_HOST='proxy.yourdie.com'
        create server Trojan-gRPC-TLS
    "

    # 测试 4: VMess-H2-TLS 批量配置生成
    run_test "VMess-H2-TLS 批量配置生成" "
        source src/core.sh
        IS_PROTOCOL='vmess'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        UUID='test-batch-vmess-h2'
        NET='h2'
        H2_PATH='/batch-vmess-h2-path'
        H2_HOST='proxy.yourdie.com'
        create server VMess-H2-TLS
    "

    # 测试 5: VMess-WS-TLS 批量配置生成
    run_test "VMess-WS-TLS 批量配置生成" "
        source src/core.sh
        IS_PROTOCOL='vmess'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        UUID='test-batch-vmess-ws'
        NET='ws'
        WS_PATH='/batch-vmess-ws-path'
        WS_HOST='proxy.yourdie.com'
        create server VMess-WS-TLS
    "

    # 测试 6: VMess-gRPC-TLS 批量配置生成
    run_test "VMess-gRPC-TLS 批量配置生成" "
        source src/core.sh
        IS_PROTOCOL='vmess'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        UUID='test-batch-vmess-grpc'
        NET='grpc'
        GRPC_SERVICE_NAME='batch-vmess-grpc'
        GRPC_HOST='proxy.yourdie.com'
        create server VMess-gRPC-TLS
    "

    # 测试总结
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
main