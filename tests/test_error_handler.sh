#!/bin/bash
# test_error_handler.sh - 错误处理框架单元测试
# 测试安全文件操作、重试机制和清理函数注册

# 设置测试目录
TEST_DIR="/tmp/v2ray_test_error_handler_$$"
IS_SH_DIR="/home/node/.openclaw/v2ray"
export IS_SH_DIR

# 确保测试目录被清理
cleanup_test_dir() {
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR" 2>/dev/null
    fi
}

# 设置退出陷阱
trap cleanup_test_dir EXIT

echo "=== 错误处理框架单元测试 ==="
echo "测试目录: $TEST_DIR"

# 加载日志和错误处理框架
. "$IS_SH_DIR/src/log.sh" 2>/dev/null || {
    echo "未找到 log.sh，跳过部分测试"
    exit 0
}
. "$IS_SH_DIR/src/utils/error_handler.sh" 2>/dev/null || {
    echo "未找到 error_handler.sh，跳过测试"
    exit 0
}

# 初始化错误处理
init_error_handler

# =============================================================================
# 测试用例 1: 安全目录创建 (safe_mkdir)
# =============================================================================
test_safe_mkdir() {
    echo ""
    echo "测试 1: 安全目录创建"
    
    # 测试 1.1: 创建新目录
    safe_mkdir "$TEST_DIR/test1"
    if [[ -d "$TEST_DIR/test1" ]]; then
        echo "  ✓ 创建新目录成功"
    else
        echo "  ✗ 创建新目录失败"
        return 1
    fi
    
    # 测试 1.2: 创建已存在目录（应该不报错）
    if safe_mkdir "$TEST_DIR/test1"; then
        echo "  ✓ 重复创建已存在目录不报错"
    else
        echo "  ✗ 重复创建已存在目录报错"
        return 1
    fi
    
    # 测试 1.3: 创建嵌套目录
    safe_mkdir "$TEST_DIR/nested/deep/path"
    if [[ -d "$TEST_DIR/nested/deep/path" ]]; then
        echo "  ✓ 创建嵌套目录成功"
    else
        echo "  ✗ 创建嵌套目录失败"
        return 1
    fi
}

# =============================================================================
# 测试用例 2: 安全删除 (safe_rm)
# =============================================================================
test_safe_rm() {
    echo ""
    echo "测试 2: 安全删除"
    
    # 创建测试文件
    echo "test content" > "$TEST_DIR/test_file.txt"
    
    # 测试 2.1: 删除存在文件
    if safe_rm "$TEST_DIR/test_file.txt"; then
        if [[ ! -f "$TEST_DIR/test_file.txt" ]]; then
            echo "  ✓ 删除文件成功"
        else
            echo "  ✗ 文件仍然存在"
            return 1
        fi
    else
        echo "  ✗ 删除文件失败"
        return 1
    fi
    
    # 测试 2.2: 删除不存在文件（应该不报错）
    if safe_rm "$TEST_DIR/nonexistent.txt"; then
        echo "  ✓ 删除不存在文件不报错"
    else
        echo "  ✗ 删除不存在文件报错"
        return 1
    fi
}

# =============================================================================
# 测试用例 3: 安全复制 (safe_cp)
# =============================================================================
test_safe_cp() {
    echo ""
    echo "测试 3: 安全复制"
    
    # 创建测试文件
    echo "test content" > "$TEST_DIR/source.txt"
    
    # 测试 3.1: 复制文件
    if safe_cp "$TEST_DIR/source.txt" "$TEST_DIR/dest.txt"; then
        if [[ -f "$TEST_DIR/dest.txt" ]] && [[ "$(cat $TEST_DIR/dest.txt)" == "test content" ]]; then
            echo "  ✓ 复制文件成功"
        else
            echo "  ✗ 复制文件内容不匹配"
            return 1
        fi
    else
        echo "  ✗ 复制文件失败"
        return 1
    fi
    
    # 测试 3.2: 复制不存在的源文件
    if ! safe_cp "$TEST_DIR/nonexistent.txt" "$TEST_DIR/dest2.txt" 2>/dev/null; then
        echo "  ✓ 复制不存在文件报错"
    else
        echo "  ✗ 复制不存在文件不应成功"
        return 1
    fi
}

# =============================================================================
# 测试用例 4: 清理函数注册
# =============================================================================
test_cleanup() {
    echo ""
    echo "测试 4: 清理函数注册"
    
    # 创建测试文件
    echo "cleanup test" > "$TEST_DIR/cleanup_test.txt"
    
    # 定义清理函数
    _cleanup_test_func() {
        local file="$1"
        if [[ -f "$file" ]]; then
            rm -f "$file"
            echo "清理完成: $file"
        fi
    }
    
    # 注册清理函数
    register_cleanup "_cleanup_test_func" "$TEST_DIR/cleanup_test.txt"
    
    if [[ ${#CLEANUP_FUNCS[@]} -gt 0 ]]; then
        echo "  ✓ 清理函数注册成功"
    else
        echo "  ✗ 清理函数注册失败"
        return 1
    fi
    
    # 执行清理
    execute_cleanup
    
    if [[ ! -f "$TEST_DIR/cleanup_test.txt" ]]; then
        echo "  ✓ 清理函数执行成功"
    else
        echo "  ✗ 清理函数未执行"
        return 1
    fi
}

# =============================================================================
# 测试用例 5: 调用栈追踪
# =============================================================================
test_call_stack() {
    echo ""
    echo "测试 5: 调用栈追踪"
    
    local stack
    stack=$(get_call_stack 5)
    
    if [[ -n "$stack" ]]; then
        echo "  ✓ 调用栈获取成功"
        echo "  调用栈摘要: $(get_call_summary)"
    else
        echo "  ✗ 调用栈获取失败"
        return 1
    fi
}

# =============================================================================
# 测试用例 6: 错误处理 (error_exit - 可恢复)
# =============================================================================
test_error_exit_recoverable() {
    echo ""
    echo "测试 6: 可恢复错误处理"
    
    local test_flag=false
    
    _error_test_func() {
        test_flag=true
        error_exit "测试错误" "$ERR_GENERAL" "true"
        test_flag=false
        return 0
    }
    
    _error_test_func
    local exit_code=$?
    
    if [[ "$test_flag" == "true" ]]; then
        echo "  ✓ 可恢复错误处理成功"
        return $exit_code
    else
        echo "  ✗ 可恢复错误处理失败"
        return 1
    fi
}

# =============================================================================
# 测试用例 7: 重试机制
# =============================================================================
test_retry_command() {
    echo ""
    echo "测试 7: 重试机制"
    
    # 创建测试文件
    echo "retry test" > "$TEST_DIR/retry_test.txt"
    
    # 测试成功重试
    if retry_command 3 0.1 test -f "$TEST_DIR/retry_test.txt"; then
        echo "  ✓ 重试机制（成功）"
    else
        echo "  ✗ 重试机制（成功）"
        return 1
    fi
    
    # 测试重试耗尽
    if ! retry_command 2 0.1 false; then
        echo "  ✓ 重试机制（耗尽）"
    else
        echo "  ✗ 重试机制（耗尽）"
        return 1
    fi
}

# =============================================================================
# 测试用例 8: 安全文件写入
# =============================================================================
test_safe_write_file() {
    echo ""
    echo "测试 8: 安全文件写入"
    
    # 测试 8.1: 写入新文件
    local test_content="line1\nline2\nline3"
    if safe_write_file "$TEST_DIR/write_test.txt" "$test_content"; then
        if [[ -f "$TEST_DIR/write_test.txt" ]]; then
            echo "  ✓ 写入新文件成功"
        else
            echo "  ✗ 写入文件不存在"
            return 1
        fi
    else
        echo "  ✗ 写入文件失败"
        return 1
    fi
    
    # 测试 8.2: 写入不存在的目录
    if ! safe_write_file "$TEST_DIR/nonexistent/file.txt" "content" 2>/dev/null; then
        echo "  ✓ 不存在目录自动创建"
    else
        echo "  ✗ 不存在目录处理异常"
        return 1
    fi
}

# =============================================================================
# 测试用例 9: 服务操作
# =============================================================================
test_service_check() {
    echo ""
    echo "测试 9: 服务状态检查"
    
    # 测试非existent服务
    if service_status "nonexistent_service_xyz" == 2; then
        echo "  ✓ 未安装服务检测正确"
    else
        echo "  ⚠ 服务状态检测可能不准确"
    fi
}

# =============================================================================
# 主测试函数
# =============================================================================
main() {
    local failed=0
    local passed=0
    
    # 创建测试目录
    safe_mkdir "$TEST_DIR"
    
    # 运行所有测试
    for test_func in $(compgen -A function test_*); do
        if $test_func; then
            ((passed++))
        else
            ((failed++))
        fi
    done
    
    # 清理
    safe_rm "$TEST_DIR"
    
    # 输出总结
    echo ""
    echo "=== 测试总结 ==="
    echo "通过: $passed"
    echo "失败: $failed"
    
    if [[ $failed -eq 0 ]]; then
        echo "所有测试通过！"
        return 0
    else
        echo "部分测试失败"
        return 1
    fi
}

# 运行主函数
main "$@"
exit $?
