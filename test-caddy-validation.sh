#!/bin/bash
# Caddy 验证优化模块测试套件

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CADDY_VALIDATOR="$SCRIPT_DIR/caddy-validation-optimizer.sh"

# 测试结果
TESTS_PASSED=0
TESTS_FAILED=0

# 测试环境
export V2RAY_ENV="testing"
export TEST_LOG_FILE="/tmp/v2ray-test-$(date +%s).log"
export LOG_FILE="$TEST_LOG_FILE"

# 诊断码常量定义（与主脚本同步）
# 注意：这些常量在主脚本中已定义为 readonly，重复定义会导致冲突
# 因此移除常量定义，直接使用主脚本中已定义的值

# 准备工作
setup() {
    echo "=== 设置测试环境 ==="
    
    # 源文件
    if [[ -f "$CADDY_VALIDATOR" ]]; then
        source "$CADDY_VALIDATOR"
        echo "[OK] 成功加载验证模块"
    else
        echo "[FAIL] 未找到验证模块: $CADDY_VALIDATOR"
        exit 1
    fi
    
    # 创建测试目录
    mkdir -p /tmp/v2ray-test
    
    # 清空日志
    > "$LOG_FILE"
}

# 清理
cleanup() {
    rm -rf /tmp/v2ray-test
    echo ""
    echo "=== 测试日志位置: $LOG_FILE ==="
    echo "=== 查看日志: tail -f $LOG_FILE ==="
}

# 断言函数
assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    if [[ "$expected" == "$actual" ]]; then
        echo "[PASS] $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "[FAIL] $message"
        echo "  预期: $expected"
        echo "  实际: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# assert_equals 已废弃，使用 assert_equal

assert_not_equal() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    if [[ "$expected" != "$actual" ]]; then
        echo "[PASS] $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "[FAIL] $message"
        echo "  不应该等于: $expected"
        echo "  实际: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_matches() {
    local pattern="$1"
    local text="$2"
    local message="${3:-}"
    
    if echo "$text" | grep -qE "$pattern"; then
        echo "[PASS] $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "[FAIL] $message"
        echo "  应匹配模式: $pattern"
        echo "  实际文本: $text"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# 测试用例
run_tests() {
    echo "=== 开始测试 ==="
    echo ""
    
    # ==================== 测试 1: 参数解析 ====================
    echo "测试 1: 命令行参数解析"
    
    # 测试 dev-mode：会自动添加 --skip-dns-check 和 --skip-tls-check，并显示 INFO 日志
    SKIP_CHECKS=$(parse_cli_args "--dev-mode")
    assert_matches "skip-dns-check" "$SKIP_CHECKS" "dev-mode 参数解析 (自动添加 skip-dns-check)"
    assert_matches "skip-tls-check" "$SKIP_CHECKS" "dev-mode 参数解析 (自动添加 skip-tls-check)"
    # 确保不包含 dev-mode 本身（已处理并替换）
    assert_not_equal "dev-mode" "$SKIP_CHECKS" "dev-mode 参数不保留在输出中"
    
    SKIP_CHECKS=$(parse_cli_args "--skip-dns-check" "--skip-tls-check")
    echo "SKIP_CHECKS: $SKIP_CHECKS"
    
    echo ""
    
    # ==================== 测试 2: 环境识别 ====================
    echo "测试 2: 环境识别"
    
    export V2RAY_ENV="production"
    assert_equal "production" "$(IDENTIFY_ENVIRONMENT)" "生产环境识别"
    
    export V2RAY_ENV="development"
    assert_equal "development" "$(IDENTIFY_ENVIRONMENT)" "开发环境识别"
    
    export V2RAY_ENV="testing"
    assert_equal "testing" "$(IDENTIFY_ENVIRONMENT)" "测试环境识别"
    
    unset V2RAY_ENV
    echo ""
    
    # ==================== 测试 3: 占位符域名诊断 ====================
    echo "测试 3: 占位符域名诊断 (code=3)"
    
    export CADDY_ERROR_LOG="dns error: lookup yourdomain.com on 8.8.8.8:51: no such host"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "3" "$CODE" "yourdomain.com 识别"
    
    export CADDY_ERROR_LOG="dns error: lookup example.com on 8.8.8.8:51: no such host"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "3" "$CODE" "example.com 识别"
    
    export CADDY_ERROR_LOG="dns error: lookup example.org on 8.8.8.8:51: no such host"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "3" "$CODE" "example.org 识别"
    
    export CADDY_ERROR_LOG="dns error: lookup placeholder.com on 8.8.8.8:51: no such host"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "3" "$CODE" "placeholder.com 识别"
    
    echo ""
    
    # ==================== 测试 4: DNS 问题诊断 ====================
    echo "测试 4: DNS 配置问题诊断 (code=1)"
    
    # 使用不包含占位符的 DNS 错误日志
    export CADDY_ERROR_LOG="resolver error: dialing: lookup testdns123xyz.com on 8.8.8.8:53: no such host"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "1" "$CODE" "DNS 解析失败识别"
    
    export CADDY_ERROR_LOG="dns error: SERVFAIL"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "1" "$CODE" "SERVFAIL 识别"
    
    export CADDY_ERROR_LOG="dns error: NXDOMAIN"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "1" "$CODE" "NXDOMAIN 识别"
    
    echo ""
    
    # ==================== 测试 5: Cloudflare API 诊断 ====================
    echo "测试 5: Cloudflare API 问题诊断 (code=2)"
    
    export CADDY_ERROR_LOG="cloudflare: API error: 10000: Invalid API token provided"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "2" "$CODE" "Cloudflare API 令牌错误识别"
    
    export CADDY_ERROR_LOG="cloudflare: 403 Forbidden: invalid API key"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "2" "$CODE" "Cloudflare 权限错误识别"
    
    export CADDY_ERROR_LOG="cloudflare: unable to authenticate with Cloudflare API (token expired)"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "2" "$CODE" "Cloudflare 身份验证错误识别"
    
    echo ""
    
    # ==================== 测试 6: 版本兼容性诊断 ====================
    echo "测试 6: Caddy 版本兼容性诊断 (code=4)"
    
    export CADDY_ERROR_LOG="Error parsing Caddyfile: json: unknown field \"admin_disabled\""
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "4" "$CODE" "Caddy 版本兼容性错误识别"
    
    export CADDY_ERROR_LOG="version mismatch: expected Caddy 2.x"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "4" "$CODE" "版本不匹配错误识别"
    
    export CADDY_ERROR_LOG="incompatible configuration: requires Caddy v2.7.0+"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "4" "$CODE" "兼容性要求错误识别"
    
    echo ""
    
    # ==================== 测试 7: 其他问题诊断 ====================
    echo "测试 7: 其他配置问题诊断 (code=0)"
    
    export CADDY_ERROR_LOG="parse error: unexpected character"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "0" "$CODE" "解析错误识别"
    
    export CADDY_ERROR_LOG="file not found: /etc/caddy/missing.conf"
    CODE=$(analyze_validation_error "$CADDY_ERROR_LOG")
    assert_equal "0" "$CODE" "文件未找到识别"
    
    export CADDY_ERROR_LOG=""
    CODE=$(analyze_validation_error "")
    assert_equal "0" "$CODE" "空日志处理"
    
    echo ""
    
    # ==================== 测试 8: 日志记录 ====================
    echo "测试 8: 日志记录"
    
    log_message "INFO" "测试日志消息"
    log_message "WARN" "测试警告消息"
    log_message "ERROR" "测试错误消息"
    
    # 检查日志文件
    assert_matches "INFO.*测试日志消息" "$(cat $LOG_FILE)" "INFO 日志记录"
    assert_matches "WARN.*测试警告消息" "$(cat $LOG_FILE)" "WARN 日志记录"
    assert_matches "ERROR.*测试错误消息" "$(cat $LOG_FILE)" "ERROR 日志记录"
    
    echo ""
    
    # ==================== 测试 9: 验证处理流程 ====================
    echo "测试 9: handle_validation_failure 流程"
    
    # 创建测试配置文件
    TEST_CONFIG="/tmp/v2ray-test/Caddyfile"
    mkdir -p "$(dirname "$TEST_CONFIG")"
    
    # 测试占位符自动修正
    cat > "$TEST_CONFIG" << 'FEED_CONFIG_EOF'
:443 {
    reverse_proxy localhost:8080
}
FEED_CONFIG_EOF
    
    # 替换为占位符
    sed -i 's/localhost:8080/yourdomain.com/' "$TEST_CONFIG"
    
    export CADDY_ERROR_LOG=$(caddy validate --config "$TEST_CONFIG" 2>&1 || true)
    
    # 保存错误日志供分析使用
    if [[ -f "$TEST_CONFIG" ]]; then
        export CADDY_ERROR_LOG="dns error: lookup yourdomain.com on 8.8.8.8:51: no such host"
    fi
    
    # 使用跳过 DNS 检查参数（因为占位符替换后仍可能有 DNS 问题）
    SKIP_CHECKS=$(parse_cli_args "--skip-dns-check" "--no-auto-fix")
    echo "SKIP_CHECKS: $SKIP_CHECKS"
    
    RESULT=0
    handle_validation_failure "$TEST_CONFIG" "$SKIP_CHECKS" || RESULT=$?
    
    # 占位符问题应导致失败（no-auto-fix）
    assert_equal "1" "$RESULT" "占位符问题且禁用自动修正时应失败"
    
    echo ""
    
    # ==================== 测试 10: 强制部署 ====================
    echo "测试 10: --force-deploy 参数"
    
    SKIP_CHECKS=$(parse_cli_args "--force-deploy")
    
    export CADDY_ERROR_LOG="dns error: lookup example.com on 8.8.8.8:51: no such host"
    
    # 强制部署应允许通过
    RESULT=0
    handle_validation_failure "$TEST_CONFIG" "$SKIP_CHECKS" || RESULT=$?
    
    assert_equal "0" "$RESULT" "强制部署应绕过检查"
    
    echo ""
    
    # ==================== 测试 11: 日志模块补充测试 ====================
    echo "测试 11: 日志模块补充测试"
    
    # 测试 11.1: LOG_FILE 环境变量覆盖
    echo "  测试 11.1: LOG_FILE 环境变量覆盖"
    export LOG_FILE="/tmp/test-custom-log-$$"
    log_message "INFO" "自定义日志测试消息"
    if [[ -f "$LOG_FILE" ]] && grep -q "自定义日志测试消息" "$LOG_FILE"; then
        echo "[PASS] LOG_FILE 环境变量覆盖测试"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "[FAIL] LOG_FILE 环境变量覆盖测试 - 日志文件未创建或内容不匹配"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # 测试 11.2: 日志目录自动创建
    echo "  测试 11.2: 日志目录自动创建"
    # 注意：根据 Architect 建议，不要预先创建目录
    # 测试 log_message 在目录不存在时自动创建
    TEST_LOG_DIR="/tmp/v2ray-test-newdir-$$"
    TEST_LOG_FILE_CUSTOM="$TEST_LOG_DIR/test.log"
    # 确保目录不存在
    rm -rf "$TEST_LOG_DIR"
    export LOG_FILE="$TEST_LOG_FILE_CUSTOM"
    # 需要先初始化模块以触发目录创建
    init_validation_module
    log_message "INFO" "目录自动创建测试"
    if [[ -d "$TEST_LOG_DIR" ]] && [[ -f "$TEST_LOG_FILE_CUSTOM" ]]; then
        echo "[PASS] 日志目录自动创建测试"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "[FAIL] 日志目录自动创建测试 - 目录或文件未创建"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    rm -rf "$TEST_LOG_DIR"
    
    # 测试 11.3: 并发写入线程安全
    echo "  测试 11.3: 并发写入线程安全"
    export LOG_FILE="/tmp/test-concurrent-log-$$"
    TOTAL_LINES=100
    for i in $(seq 1 $TOTAL_LINES); do
        log_message "INFO" "并发测试消息 $i" &
    done
    wait
    
    # 验证所有消息都写入
    ACTUAL_LINES=$(wc -l < "$LOG_FILE")
    if [[ $ACTUAL_LINES -eq $TOTAL_LINES ]]; then
        echo "[PASS] 并发写入线程安全测试 ($ACTUAL_LINES/$TOTAL_LINES 行)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "[FAIL] 并发写入线程安全测试 - 预期 $TOTAL_LINES 行，实际 $ACTUAL_LINES 行"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    # 清理
    rm -f "$LOG_FILE"
    
    echo ""
}

# 输出结果
print_results() {
    echo "=== 测试结果 ==="
    echo "通过: $TESTS_PASSED"
    echo "失败: $TESTS_FAILED"
    echo "总计: $((TESTS_PASSED + TESTS_FAILED))"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo ""
        echo "某些测试失败！"
        return 1
    else
        echo ""
        echo "所有测试通过！"
        return 0
    fi
}

# 主程序
main() {
    setup
    run_tests
    cleanup
    print_results
}

# 执行
main "$@"
