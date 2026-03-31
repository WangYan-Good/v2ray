#!/bin/bash
# 简单的基本功能测试

IS_SH_DIR="/home/node/.openclaw/v2ray"
TEST_DIR="/tmp/v2ray_test_$$"

# 加载模块
. "$IS_SH_DIR/src/log.sh"
. "$IS_SH_DIR/src/utils/error_handler.sh"
init_error_handler

echo "=== 基本功能测试 ==="

# 测试 safe_mkdir
echo "测试 1: safe_mkdir"
safe_mkdir "$TEST_DIR/subdir"
if [[ -d "$TEST_DIR/subdir" ]]; then
    echo "  ✓ safe_mkdir 工作正常"
else
    echo "  ✗ safe_mkdir 失败"
fi

# 测试 safe_rm
echo "测试 2: safe_rm"
echo "test" > "$TEST_DIR/test_file.txt"
safe_rm "$TEST_DIR/test_file.txt"
if [[ ! -f "$TEST_DIR/test_file.txt" ]]; then
    echo "  ✓ safe_rm 工作正常"
else
    echo "  ✗ safe_rm 失败"
fi

# 测试 safe_cp
echo "测试 3: safe_cp"
echo "content" > "$TEST_DIR/source.txt"
safe_cp "$TEST_DIR/source.txt" "$TEST_DIR/dest.txt"
if [[ -f "$TEST_DIR/dest.txt" ]] && [[ "$(cat $TEST_DIR/dest.txt)" == "content" ]]; then
    echo "  ✓ safe_cp 工作正常"
else
    echo "  ✗ safe_cp 失败"
fi

# 测试 register_cleanup
echo "测试 4: register_cleanup"
echo "cleanup test" > "$TEST_DIR/cleanup_test.txt"
_cleanup_func() {
    rm -f "$1"
}
register_cleanup "_cleanup_func" "$TEST_DIR/cleanup_test.txt"
if [[ ${#CLEANUP_FUNCS[@]} -gt 0 ]]; then
    echo "  ✓ register_cleanup 工作正常 (${#CLEANUP_FUNCS[@]} items registered)"
else
    echo "  ✗ register_cleanup 失败"
fi

# 执行清理
execute_cleanup
if [[ ! -f "$TEST_DIR/cleanup_test.txt" ]]; then
    echo "  ✓ execute_cleanup 工作正常"
else
    echo "  ✗ execute_cleanup 失败"
fi

# 测试重试
echo "测试 5: retry_command"
if retry_command 1 0.1 true; then
    echo "  ✓ retry_command 工作正常"
else
    echo "  ✗ retry_command 失败"
fi

# 测试调用栈
echo "测试 6: get_call_stack"
stack=$(get_call_stack 3)
if [[ -n "$stack" ]]; then
    echo "  ✓ get_call_stack 工作正常"
    echo "    调用栈摘要: $(get_call_summary)"
else
    echo "  ✗ get_call_stack 失败"
fi

# 清理
safe_rm "$TEST_DIR"

echo ""
echo "=== 所有测试完成 ==="
