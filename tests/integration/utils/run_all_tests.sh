#!/bin/bash
# ============================================================================
# V2Ray 集成测试运行器
# ============================================================================
# 运行所有集成测试并生成报告
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="$SCRIPT_DIR/test_report_$(date +%Y%m%d_%H%M%S).md"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}V2Ray 集成测试套件运行器${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 测试列表
declare -a TESTS=(
    "config_read_write_test.sh:配置读写一致性测试"
    "edge_cases_test.sh:边界情况测试"
    "test_get_info.sh:Get Info 功能测试"
)

# 统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# 报告内容
REPORT_CONTENT="# V2Ray 集成测试报告

**运行时间**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
**运行环境**: $(uname -a)

---

## 测试结果总览

| 测试名称 | 状态 | 时间 |
|----------|------|------|
"

run_test() {
    local test_file="$1"
    local test_name="$2"
    local test_path="$SCRIPT_DIR/$test_file"
    
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e "${BLUE}运行测试：$test_name${NC}"
    echo -e "${BLUE}文件：$test_file${NC}"
    echo ""
    
    local start_time=$(date +%s)
    
    if [[ -x "$test_path" ]]; then
        if bash "$test_path"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            echo -e "${GREEN}✓ 测试通过 (${duration}s)${NC}"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            PASSED_TESTS=$((PASSED_TESTS + 1))
            
            REPORT_CONTENT+="| $test_name | ${GREEN}✓ 通过${NC} | ${duration}s |
"
            return 0
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            echo -e "${RED}✗ 测试失败 (${duration}s)${NC}"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            FAILED_TESTS=$((FAILED_TESTS + 1))
            
            REPORT_CONTENT+="| $test_name | ${RED}✗ 失败${NC} | ${duration}s |
"
            return 1
        fi
    else
        echo -e "${YELLOW}⊘ 测试文件不存在或不可执行${NC}"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        
        REPORT_CONTENT+="| $test_name | ${YELLOW}⊘ 跳过${NC} | - |
"
        return 2
    fi
}

# 运行所有测试
echo ""
for test_entry in "${TESTS[@]}"; do
    IFS=':' read -r test_file test_name <<< "$test_entry"
    run_test "$test_file" "$test_name" || true
    echo ""
done

# 生成报告
REPORT_CONTENT+="
---

## 统计

- **总测试数**: $TOTAL_TESTS
- **通过**: $PASSED_TESTS
- **失败**: $FAILED_TESTS
- **跳过**: $SKIPPED_TESTS

---

## 结论

"

if [[ $FAILED_TESTS -eq 0 && $TOTAL_TESTS -gt 0 ]]; then
    REPORT_CONTENT+="**✓ 所有测试通过！** 🎉

修复验证成功，配置读写一致性问题已解决。
"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ 所有测试通过！${NC}"
    echo -e "${GREEN}========================================${NC}"
elif [[ $TOTAL_TESTS -eq 0 ]]; then
    REPORT_CONTENT+="**⊘ 没有运行任何测试**

请检查测试文件是否存在且可执行。
"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}⊘ 没有运行任何测试${NC}"
    echo -e "${YELLOW}========================================${NC}"
else
    REPORT_CONTENT+="**✗ 有测试失败**

请查看上面的错误输出并修复问题。
"
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ 有测试失败${NC}"
    echo -e "${RED}========================================${NC}"
fi

# 保存报告
echo "$REPORT_CONTENT" > "$REPORT_FILE"

echo ""
echo -e "${CYAN}测试报告已保存至：${NC}$REPORT_FILE"
echo ""

# 返回状态
if [[ $FAILED_TESTS -gt 0 ]]; then
    exit 1
fi
exit 0
