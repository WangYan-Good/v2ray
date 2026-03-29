#!/bin/bash
# V2Ray 批量模式 VPS 测试脚本
# 在 VPS 上执行完整批量模式测试

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
    log_info "V2Ray 批量模式 VPS 测试"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "=========================================="

    cd /home/node/.openclaw/v2ray

    # 检查 V2Ray 是否安装
    if [[ ! -f /usr/local/bin/v2ray ]]; then
        log_error "V2Ray 未安装，请先安装 V2Ray"
        exit 1
    fi

    # 启用批量模式
    export V2RAY_NON_INTERACTIVE=1

    # 测试 1: Trojan-H2-TLS
    log_test "测试 1: Trojan-H2-TLS 批量配置创建"
    ((TESTS_TOTAL++))
    if (
        source src/core.sh
        IS_PROTOCOL='trojan'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        TROJAN_PASSWORD="test-batch-h2-$(date +%s)"
        NET='h2'
        H2_PATH='/batch-h2-path'
        H2_HOST='proxy.yourdie.com'
        create server Trojan-H2-TLS 2>&1 | grep -v "ERR"
    ); then
        ((TESTS_PASSED++))
        log_success "Trojan-H2-TLS 配置创建成功"
        ls -lh /etc/v2ray/configs/Trojan-H2-TLS-* | tail -1
    else
        ((TESTS_FAILED++))
        log_error "Trojan-H2-TLS 配置创建失败"
    fi

    # 测试 2: Trojan-WS-TLS
    log_test "测试 2: Trojan-WS-TLS 批量配置创建"
    ((TESTS_TOTAL++))
    if (
        source src/core.sh
        IS_PROTOCOL='trojan'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        TROJAN_PASSWORD="test-batch-ws-$(date +%s)"
        NET='ws'
        WS_PATH='/batch-ws-path'
        WS_HOST='proxy.yourdie.com'
        create server Trojan-WS-TLS 2>&1 | grep -v "ERR"
    ); then
        ((TESTS_PASSED++))
        log_success "Trojan-WS-TLS 配置创建成功"
        ls -lh /etc/v2ray/configs/Trojan-WS-TLS-* | tail -1
    else
        ((TESTS_FAILED++))
        log_error "Trojan-WS-TLS 配置创建失败"
    fi

    # 测试 3: Trojan-gRPC-TLS
    log_test "测试 3: Trojan-gRPC-TLS 批量配置创建"
    ((TESTS_TOTAL++))
    if (
        source src/core.sh
        IS_PROTOCOL='trojan'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        TROJAN_PASSWORD="test-batch-grpc-$(date +%s)"
        NET='grpc'
        GRPC_SERVICE_NAME="batch-grpc-service"
        GRPC_HOST='proxy.yourdie.com'
        create server Trojan-gRPC-TLS 2>&1 | grep -v "ERR"
    ); then
        ((TESTS_PASSED++))
        log_success "Trojan-gRPC-TLS 配置创建成功"
        ls -lh /etc/v2ray/configs/Trojan-gRPC-TLS-* | tail -1
    else
        ((TESTS_FAILED++))
        log_error "Trojan-gRPC-TLS 配置创建失败"
    fi

    # 测试 4: VMess-H2-TLS
    log_test "测试 4: VMess-H2-TLS 批量配置创建"
    ((TESTS_TOTAL++))
    if (
        source src/core.sh
        IS_PROTOCOL='vmess'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        UUID="test-batch-vmess-h2-$(date +%s)"
        NET='h2'
        H2_PATH='/batch-vmess-h2-path'
        H2_HOST='proxy.yourdie.com'
        create server VMess-H2-TLS 2>&1 | grep -v "ERR"
    ); then
        ((TESTS_PASSED++))
        log_success "VMess-H2-TLS 配置创建成功"
        ls -lh /etc/v2ray/configs/VMess-H2-TLS-* | tail -1
    else
        ((TESTS_FAILED++))
        log_error "VMess-H2-TLS 配置创建失败"
    fi

    # 测试 5: VMess-WS-TLS
    log_test "测试 5: VMess-WS-TLS 批量配置创建"
    ((TESTS_TOTAL++))
    if (
        source src/core.sh
        IS_PROTOCOL='vmess'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        UUID="test-batch-vmess-ws-$(date +%s)"
        NET='ws'
        WS_PATH='/batch-vmess-ws-path'
        WS_HOST='proxy.yourdie.com'
        create server VMess-WS-TLS 2>&1 | grep -v "ERR"
    ); then
        ((TESTS_PASSED++))
        log_success "VMess-WS-TLS 配置创建成功"
        ls -lh /etc/v2ray/configs/VMess-WS-TLS-* | tail -1
    else
        ((TESTS_FAILED++))
        log_error "VMess-WS-TLS 配置创建失败"
    fi

    # 测试 6: VMess-gRPC-TLS
    log_test "测试 6: VMess-gRPC-TLS 批量配置创建"
    ((TESTS_TOTAL++))
    if (
        source src/core.sh
        IS_PROTOCOL='vmess'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        UUID="test-batch-vmess-grpc-$(date +%s)"
        NET='grpc'
        GRPC_SERVICE_NAME="batch-vmess-grpc"
        GRPC_HOST='proxy.yourdie.com'
        create server VMess-gRPC-TLS 2>&1 | grep -v "ERR"
    ); then
        ((TESTS_PASSED++))
        log_success "VMess-gRPC-TLS 配置创建成功"
        ls -lh /etc/v2ray/configs/VMess-gRPC-TLS-* | tail -1
    else
        ((TESTS_FAILED++))
        log_error "VMess-gRPC-TLS 配置创建失败"
    fi

    # 测试 7: VLESS-H2-TLS
    log_test "测试 7: VLESS-H2-TLS 批量配置创建"
    ((TESTS_TOTAL++))
    if (
        source src/core.sh
        IS_PROTOCOL='vless'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        UUID="test-batch-vless-h2-$(date +%s)"
        NET='h2'
        H2_PATH='/batch-vless-h2-path'
        H2_HOST='proxy.yourdie.com'
        create server VLESS-H2-TLS 2>&1 | grep -v "ERR"
    ); then
        ((TESTS_PASSED++))
        log_success "VLESS-H2-TLS 配置创建成功"
        ls -lh /etc/v2ray/configs/VLESS-H2-TLS-* | tail -1
    else
        ((TESTS_FAILED++))
        log_error "VLESS-H2-TLS 配置创建失败"
    fi

    # 测试 8: VLESS-WS-TLS
    log_test "测试 8: VLESS-WS-TLS 批量配置创建"
    ((TESTS_TOTAL++))
    if (
        source src/core.sh
        IS_PROTOCOL='vless'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        UUID="test-batch-vless-ws-$(date +%s)"
        NET='ws'
        WS_PATH='/batch-vless-ws-path'
        WS_HOST='proxy.yourdie.com'
        create server VLESS-WS-TLS 2>&1 | grep -v "ERR"
    ); then
        ((TESTS_PASSED++))
        log_success "VLESS-WS-TLS 配置创建成功"
        ls -lh /etc/v2ray/configs/VLESS-WS-TLS-* | tail -1
    else
        ((TESTS_FAILED++))
        log_error "VLESS-WS-TLS 配置创建失败"
    fi

    # 测试 9: VLESS-gRPC-TLS
    log_test "测试 9: VLESS-gRPC-TLS 批量配置创建"
    ((TESTS_TOTAL++))
    if (
        source src/core.sh
        IS_PROTOCOL='vless'
        IS_ADDR='proxy.yourdie.com'
        PORT='443'
        UUID="test-batch-vless-grpc-$(date +%s)"
        NET='grpc'
        GRPC_SERVICE_NAME="batch-vless-grpc"
        GRPC_HOST='proxy.yourdie.com'
        create server VLESS-gRPC-TLS 2>&1 | grep -v "ERR"
    ); then
        ((TESTS_PASSED++))
        log_success "VLESS-gRPC-TLS 配置创建成功"
        ls -lh /etc/v2ray/configs/VLESS-gRPC-TLS-* | tail -1
    else
        ((TESTS_FAILED++))
        log_error "VLESS-gRPC-TLS 配置创建失败"
    fi

    # 显示所有创建的配置文件
    log_info ""
    log_info "=========================================="
    log_info "所有创建的配置文件"
    log_info "=========================================="
    ls -lh /etc/v2ray/configs/*.json | tail -10

    # 测试总结
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
main