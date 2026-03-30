#!/bin/bash
# 验证所有 P0 修复

echo "=== 验证 P0 级别修复 ==="
echo ""

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计数器
PASSED=0
FAILED=0

# 测试函数
test_result() {
    local test_name="$1"
    local result="$2"
    
    if [[ "$result" == "0" ]]; then
        echo "[PASS] $test_name"
        PASSED=$((PASSED + 1))
    else
        echo "[FAIL] $test_name"
        FAILED=$((FAILED + 1))
    fi
}

# 测试 1: 诊断码常量定义
echo "测试 1: 诊断码常量定义"
code=$(bash -c "source $SCRIPT_DIR/caddy-validation-optimizer.sh 2>/dev/null && echo \$DIAG_CODE_OTHER \$DIAG_CODE_DNS \$DIAG_CODE_CLOUDFLARE \$DIAG_CODE_PLACEHOLDER \$DIAG_CODE_VERSION")
expected="0 1 2 3 4"
if [[ "$code" == "$expected" ]]; then
    test_result "诊断码常量定义" "0"
else
    test_result "诊断码常量定义 (期望: $expected, 实际: $code)" "1"
fi

# 测试 2: 占位符域名诊断
echo ""
echo "测试 2: 占位符域名诊断"
code=$(bash -c "source $SCRIPT_DIR/caddy-validation-optimizer.sh 2>/dev/null && analyze_validation_error 'dns error: lookup yourdomain.com on 8.8.8.8:51: no such host'")
if [[ "$code" == "3" ]]; then
    test_result "占位符域名诊断 (code=3)" "0"
else
    test_result "占位符域名诊断" "1"
fi

# 测试 3: DNS 诊断
echo ""
echo "测试 3: DNS 诊断"
code=$(bash -c "source $SCRIPT_DIR/caddy-validation-optimizer.sh 2>/dev/null && analyze_validation_error 'dns resolver error: dialing: some-nonexistent-domain.com on 8.8.8.8:53: no such host'")
if [[ "$code" == "1" ]]; then
    test_result "DNS 诊断 (code=1)" "0"
else
    test_result "DNS 诊断" "1"
fi

# 测试 4: Cloudflare 诊断
echo ""
echo "测试 4: Cloudflare 诊断"
code=$(bash -c "source $SCRIPT_DIR/caddy-validation-optimizer.sh 2>/dev/null && analyze_validation_error 'cloudflare: API error: 10000: Invalid API token provided'")
if [[ "$code" == "2" ]]; then
    test_result "Cloudflare 诊断 (code=2)" "0"
else
    test_result "Cloudflare 诊断" "1"
fi

# 测试 5: 参数解析
echo ""
echo "测试 5: 参数解析"
output=$(bash -c "source $SCRIPT_DIR/caddy-validation-optimizer.sh 2>/dev/null && parse_cli_args '--skip-dns-check' '--skip-tls-check'")
if [[ "$output" == *"skip-dns-check"* ]] && [[ "$output" == *"skip-tls-check"* ]]; then
    test_result "参数解析" "0"
else
    test_result "参数解析" "1"
fi

# 测试 6: 测试脚本语法检查
echo ""
echo "测试 6: 测试脚本语法检查"
if bash -n "$SCRIPT_DIR/test-caddy-validation.sh" 2>/dev/null; then
    test_result "测试脚本语法检查" "0"
else
    test_result "测试脚本语法检查" "1"
fi

# 测试 7: pytest 测试框架存在
echo ""
echo "测试 7: pytest 测试框架存在"
if [[ -d "$SCRIPT_DIR/tests" ]]; then
    test_result "pytest 测试框架目录" "0"
else
    test_result "pytest 测试框架目录" "1"
fi

# 测试 8: 测试文件存在
echo ""
echo "测试 8: 测试文件存在"
test_files=(
    "test_diagnosis.py"
    "test_auto_correct.py"
    "test_environment_consistency.py"
    "test_override_flags.py"
    "test_edge_cases.py"
    "test_logging.py"
    "test_permissions.py"
    "test_parameter_combinations.py"
    "test_non_interactive.py"
    "test_e2e.py"
)

for file in "${test_files[@]}"; do
    if [[ -f "$SCRIPT_DIR/tests/$file" ]]; then
        test_result "测试文件存在: $file" "0"
    else
        test_result "测试文件存在: $file" "1"
    fi
done

# 测试 9: CI/CD 配置文件存在
echo ""
echo "测试 9: CI/CD 配置文件存在"
if [[ -f "$SCRIPT_DIR/.github/workflows/test.yml" ]]; then
    test_result "GitHub Actions workflow" "0"
else
    test_result "GitHub Actions workflow" "1"
fi

# 输出结果
echo ""
echo "=== 验证结果 ==="
echo "通过: $PASSED"
echo "失败: $FAILED"
echo "总计: $((PASSED + FAILED))"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "某些验证失败！"
    exit 1
else
    echo ""
    echo "所有验证通过！P0 问题已修复完成。"
    exit 0
fi
