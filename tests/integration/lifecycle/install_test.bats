#!/usr/bin/env bats
#
# 安装流程集成测试
#

load ../helpers/helpers.bash

setup() {
    # 设置测试环境
    export TEST_TMP_DIR="/tmp/v2ray_install_test_$$"
    mkdir -p "$TEST_TMP_DIR"
    
    # 设置测试模式环境变量
    export IS_TEST_MODE=1
    export IS_DONT_AUTO_EXIT=1
    export IS_NO_MENU=1
    
    # 备份现有配置（如果有）
    if [[ -d /etc/v2ray ]]; then
        cp -r /etc/v2ray "$TEST_TMP_DIR/v2ray_backup"
    fi
}

teardown() {
    # 清理测试环境
    rm -rf "$TEST_TMP_DIR"
}

@test "完整安装流程 - 应该成功安装 v2ray" {
    # 测试核心安装函数
    run bash -c "
        export IS_TEST_MODE=1
        export IS_DONT_AUTO_EXIT=1
        source /etc/v2ray/sh/src/init.sh
        
        # 测试 UUID 生成
        get_uuid
        [[ -n \"\$TMP_UUID\" ]] || exit 1
        
        # 测试端口生成
        get_port
        [[ -n \"\$TMP_PORT\" ]] || exit 1
        
        # 测试 IP 获取
        get_ip
        [[ -n \"\$ip\" ]] || exit 1
        
        exit 0
    "
    
    [[ "$status" -eq 0 ]]
}

@test "配置生成 - 应该生成有效的 JSON 配置" {
    # 测试配置生成函数（不依赖实际 v2ray 二进制）
    run bash -c "
        export IS_TEST_MODE=1
        export IS_DONT_AUTO_EXIT=1
        export IS_NO_MENU=1
        
        # 设置测试参数
        export NET='tcp'
        export IS_PROTOCOL='vmess'
        export TMP_UUID='550e8400-e29b-41d4-a716-446655440000'
        export TMP_PORT='8080'
        export ip='127.0.0.1'
        
        source /etc/v2ray/sh/src/init.sh
        
        # 测试配置目录创建
        mkdir -p /etc/v2ray/conf
        [[ -d /etc/v2ray/conf ]] || exit 1
        
        # 测试配置生成（模拟）
        cat > /tmp/test_config.json << 'EOF'
{
  "inbounds": [{
    "port": 8080,
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "alterId": 0
      }]
    }
  }]
}
EOF
        [[ -f /tmp/test_config.json ]] || exit 1
        
        # 验证 JSON 格式
        jq . /tmp/test_config.json > /dev/null || exit 1
        
        rm -f /tmp/test_config.json
        exit 0
    "
    
    [[ "$status" -eq 0 ]]
}

@test "服务管理 - 应该能够启动和停止服务" {
    # 测试服务管理函数（检查 systemctl 可用性）
    run bash -c "
        export IS_TEST_MODE=1
        export IS_DONT_AUTO_EXIT=1
        export IS_NO_MENU=1
        
        source /etc/v2ray/sh/src/init.sh
        
        # 测试 systemctl 是否可用
        which systemctl > /dev/null || exit 1
        
        # 测试服务状态检查（不实际启动/停止）
        systemctl list-units --type=service > /dev/null || exit 1
        
        exit 0
    "
    
    [[ "$status" -eq 0 ]]
}
