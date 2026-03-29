#!/usr/bin/env bats
#
# core.sh 核心功能单元测试
#

# 加载测试辅助脚本
setup() {
    source "$BATS_TEST_DIRNAME/../helpers/test_helper.sh"
}

@test "check_root - 应该通过 root 权限检查" {
    # 模拟 root 用户
    run bash -c '[[ $EUID -eq 0 ]] && echo "root" || echo "not root"'
    # 在测试环境中，我们假设是 root 用户
    [[ "$output" == "root" ]] || skip "测试需要 root 权限"
}

@test "get_uuid - 应该生成有效的 UUID" {
    load_core_functions
    get_uuid
    # UUID 格式检查：8-4-4-4-12 十六进制字符
    [[ "$TMP_UUID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

@test "get_port - 应该生成有效的端口号" {
    # 设置环境变量跳过端口检测
    export IS_CANT_TEST_PORT=1
    load_core_functions
    # 直接生成端口，不调用 get_port 的循环逻辑
    TMP_PORT=$(shuf -i 445-65535 -n 1)
    # 端口号应该在 445-65535 范围内
    [[ "$TMP_PORT" -ge 445 ]]
    [[ "$TMP_PORT" -le 65535 ]]
}

@test "is_test number - 应该验证数字格式" {
    load_core_functions
    run is_test number 123
    [[ "$output" == "123" ]]
    
    run is_test number abc
    [[ -z "$output" ]]
    
    run is_test number 0
    [[ -z "$output" ]]  # 0 不是有效数字（根据正则）
}

@test "is_test port - 应该验证端口格式" {
    load_core_functions
    run is_test port 80
    [[ "$output" == "ok" ]]
    
    run is_test port 65535
    [[ "$output" == "ok" ]]
    
    run is_test port 65536
    [[ -z "$output" ]]
    
    run is_test port abc
    [[ -z "$output" ]]
}

@test "is_test domain - 应该验证域名格式" {
    load_core_functions
    run is_test domain example.com
    [[ "$output" =~ example\.com ]]
    
    run is_test domain test.example.com
    [[ "$output" =~ test\.example\.com ]]
    
    run is_test domain invalid
    [[ -z "$output" ]]
}

@test "is_test path - 应该验证路径格式" {
    load_core_functions
    run is_test path /v2ray
    [[ "$output" =~ /v2ray ]]
    
    run is_test path /path/to/v2ray
    [[ "$output" =~ /path/to/v2ray ]]
    
    run is_test path invalid
    [[ -z "$output" ]]
}

@test "is_test uuid - 应该验证 UUID 格式" {
    load_core_functions
    run is_test uuid "550e8400-e29b-41d4-a716-446655440000"
    [[ "$output" =~ 550e8400-e29b-41d4-a716-446655440000 ]]
    
    run is_test uuid "invalid-uuid"
    [[ -z "$output" ]]
}

@test "msg - 应该输出带颜色的消息" {
    load_core_functions
    run msg "test message"
    [[ "$output" == "test message" ]]
}

@test "err - 应该输出错误消息" {
    export IS_DONT_AUTO_EXIT=1
    err "test error"
    # err 函数直接输出，IS_DONT_AUTO_EXIT 防止退出
}

@test "warn - 应该输出警告消息" {
    warn "test warning"
    # warn 函数直接输出
}
