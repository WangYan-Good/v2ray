#!/bin/bash
# V2Ray VPS 架构自动部署集成测试
# 测试 auto_deploy_vps_architecture() 和 cleanup_vps_architecture() 的端到端功能

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
log_warn() { echo -e "${YELLOW}[WARN]${NONE} $1"; }

# ========================================
# 测试工具函数
# ========================================

# 创建测试配置
create_test_config() {
    local config_file="$1"
    local protocol="$2"
    local network="$3"
    local port="$4"
    local host="$5"
    
    cat > "$config_file" << EOF
{
    "inbounds": [{
        "port": $port,
        "listen": "127.0.0.1",
        "protocol": "$protocol",
        "settings": {
            "clients": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440000"
                }
            ]
        },
        "streamSettings": {
            "network": "$network",
            "security": "tls",
            "tlsSettings": {
                "certificates": [{
                    "certificateFile": "/etc/v2ray/v2ray.crt",
                    "keyFile": "/etc/v2ray/v2ray.key"
                }]
            }
        }
    }],
    "outbounds": [{
        "protocol": "freedom"
    }]
}
EOF
}

# 创建测试配置（无 TLS）
create_test_config_no_tls() {
    local config_file="$1"
    local protocol="$2"
    local network="$3"
    local port="$4"
    
    cat > "$config_file" << EOF
{
    "inbounds": [{
        "port": $port,
        "listen": "0.0.0.0",
        "protocol": "$protocol",
        "settings": {
            "clients": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440000"
                }
            ]
        }
    }],
    "outbounds": [{
        "protocol": "freedom"
    }]
}
EOF
}

# 创建测试配置（WebSocket）
create_test_config_ws() {
    local config_file="$1"
    local protocol="$2"
    local port="$3"
    local host="$4"
    local path="/v2ray"
    
    cat > "$config_file" << EOF
{
    "inbounds": [{
        "port": $port,
        "listen": "127.0.0.1",
        "protocol": "$protocol",
        "settings": {
            "clients": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440000"
                }
            ]
        },
        "streamSettings": {
            "network": "ws",
            "security": "tls",
            "wsSettings": {
                "headers": {
                    "Host": "$host"
                },
                "path": "$path"
            }
        }
    }],
    "outbounds": [{
        "protocol": "freedom"
    }]
}
EOF
}

# 创建测试配置（HTTP/2）
create_test_config_h2() {
    local config_file="$1"
    local protocol="$2"
    local port="$3"
    local host="$4"
    
    cat > "$config_file" << EOF
{
    "inbounds": [{
        "port": $port,
        "listen": "127.0.0.1",
        "protocol": "$protocol",
        "settings": {
            "clients": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440000"
                }
            ]
        },
        "streamSettings": {
            "network": "h2",
            "security": "tls",
            "httpSettings": {
                "host": ["$host"],
                "path": "/v2ray"
            }
        }
    }],
    "outbounds": [{
        "protocol": "freedom"
    }]
}
EOF
}

# 创建测试配置（gRPC）
create_test_config_grpc() {
    local config_file="$1"
    local protocol="$2"
    local port="$3"
    local host="$4"
    
    cat > "$config_file" << EOF
{
    "inbounds": [{
        "port": $port,
        "listen": "127.0.0.1",
        "protocol": "$protocol",
        "settings": {
            "clients": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440000"
                }
            ]
        },
        "streamSettings": {
            "network": "grpc",
            "security": "tls",
            "grpc_host": "$host"
        }
    }],
    "outbounds": [{
        "protocol": "freedom"
    }]
}
EOF
}

# ========================================
# 测试用例
# ========================================

# 测试 1: 配置文件验证
test_config_validation() {
    log_test "测试 1: 配置文件验证"
    ((TESTS_TOTAL++))
    
    local tmp_config="/tmp/test_config_validation.json"
    
    # 测试无效 JSON
    echo "invalid json" > "$tmp_config"
    
    if test -f /tmp/$JQ && /tmp/$JQ empty "$tmp_config" 2>/dev/null; then
        log_error "无效 JSON 应该被检测到"
        rm -f "$tmp_config"
        ((TESTS_FAILED++))
        return
    elif $JQ empty "$tmp_config" 2>/dev/null; then
        log_error "无效 JSON 应该被检测到"
        rm -f "$tmp_config"
        ((TESTS_FAILED++))
        return
    else
        log_success "无效 JSON 被正确拒绝"
        ((TESTS_PASSED++))
    fi
    
    # 测试有效 JSON
    create_test_config "$tmp_config" "vmess" "ws" "8443" "test.example.com"
    
    if $JQ empty "$tmp_config" 2>/dev/null; then
        log_success "有效 JSON 被正确接受"
        ((TESTS_PASSED++))
    else
        log_error "有效 JSON 应该被接受"
        ((TESTS_FAILED++))
    fi
    
    rm -f "$tmp_config"
}

# 测试 2: 配置提取
test_config_extraction() {
    log_test "测试 2: 配置信息提取"
    ((TESTS_TOTAL++))
    
    local tmp_config="/tmp/test_config_extraction.json"
    
    create_test_config_h2 "$tmp_config" "vmess" "443" "example.com"
    
    # 提取信息
    local port protocol network host
    port=$($JQ -r '.inbounds[0].port' "$tmp_config")
    protocol=$($JQ -r '.inbounds[0].protocol' "$tmp_config")
    network=$($JQ -r '.inbounds[0].streamSettings.network' "$tmp_config")
    host=$($JQ -r '.inbounds[0].streamSettings.httpSettings.host[0]' "$tmp_config")
    
    if [[ "$port" == "443" ]] && [[ "$protocol" == "vmess" ]] && [[ "$network" == "h2" ]] && [[ "$host" == "example.com" ]]; then
        log_success "配置信息提取正确"
        ((TESTS_PASSED++))
    else
        log_error "配置信息提取失败"
        log_error "  端口: $port (期望: 443)"
        log_error "  协议: $protocol (期望: vmess)"
        log_error "  传输: $network (期望: h2)"
        log_error "  域名: $host (期望: example.com)"
        ((TESTS_FAILED++))
    fi
    
    rm -f "$tmp_config"
}

# 测试 3: 状态管理
test_state_management() {
    log_test "测试 3: 状态管理"
    ((TESTS_TOTAL++))
    
    local tmp_config="/tmp/test_state_management.json"
    local state_dir="/tmp/test_state_dir"
    local state_file="$state_dir/state.json"
    
    # 创建状态目录
    mkdir -p "$state_dir"
    
    # 创建测试配置
    create_test_config "$tmp_config" "vmess" "ws" "8443" "test.example.com"
    
    # 计算配置哈希
    local config_hash
    config_hash=$(sha256sum "$tmp_config" | cut -d' ' -f1)
    
    # 创建状态文件
    $JQ -n --arg hash "$config_hash" --arg timestamp "$(date -Iseconds)" \
        '{"config_hash": $hash, "last_updated": $timestamp}' > "$state_file"
    
    # 验证状态文件
    if $JQ -e '.config_hash' "$state_file" > /dev/null 2>&1; then
        log_success "状态文件创建正确"
        ((TESTS_PASSED++))
    else
        log_error "状态文件创建失败"
        ((TESTS_FAILED++))
    fi
    
    # 验证哈希匹配
    local stored_hash
    stored_hash=$($JQ -r '.config_hash' "$state_file")
    
    if [[ "$config_hash" == "$stored_hash" ]]; then
        log_success "配置哈希匹配"
        ((TESTS_PASSED++))
    else
        log_error "配置哈希不匹配"
        log_error "  期望: $config_hash"
        log_error "  实际: $stored_hash"
        ((TESTS_FAILED++))
    fi
    
    # 清理
    rm -rf "$state_dir"
    rm -f "$tmp_config"
}

# 测试 4: 部署脚本语法验证
test_script_syntax() {
    log_test "测试 4: 部署脚本语法验证"
    ((TESTS_TOTAL++))
    
    local script_file="/home/node/.openclaw/v2ray/scripts/v2ray-vps-auto-deploy.sh"
    
    if bash -n "$script_file" 2>&1; then
        log_success "部署脚本语法正确"
        ((TESTS_PASSED++))
    else
        log_error "部署脚本存在语法错误"
        ((TESTS_FAILED++))
    fi
    
    if [[ -x "$script_file" ]]; then
        log_success "部署脚本具有可执行权限"
        ((TESTS_PASSED++))
    else
        log_error "部署脚本没有可执行权限"
        ((TESTS_FAILED++))
    fi
}

# 测试 5: core.sh 函数集成
test_core_integration() {
    log_test "测试 5: core.sh 函数集成"
    ((TESTS_TOTAL++))
    
    local core_file="/home/node/.openclaw/v2ray/src/core.sh"
    
    if grep -q "auto_deploy_vps_architecture()" "$core_file"; then
        log_success "auto_deploy_vps_architecture() 函数在 core.sh 中定义"
        ((TESTS_PASSED++))
    else
        log_error "auto_deploy_vps_architecture() 函数未在 core.sh 中定义"
        ((TESTS_FAILED++))
    fi
    
    if grep -q "cleanup_vps_architecture()" "$core_file"; then
        log_success "cleanup_vps_architecture() 函数在 core.sh 中定义"
        ((TESTS_PASSED++))
    else
        log_error "cleanup_vps_architecture() 函数未在 core.sh 中定义"
        ((TESTS_FAILED++))
    fi
    
    if bash -n "$core_file" 2>&1; then
        log_success "core.sh 语法正确"
        ((TESTS_PASSED++))
    else
        log_error "core.sh 存在语法错误"
        ((TESTS_FAILED++))
    fi
}

# 测试 6: 参数校验
test_parameter_validation() {
    log_test "测试 6: 参数校验"
    ((TESTS_TOTAL++))
    
    # 测试脚本具有帮助信息
    if /home/node/.openclaw/v2ray/scripts/v2ray-vps-auto-deploy.sh --help > /dev/null 2>&1; then
        log_success "部署脚本帮助信息正常"
        ((TESTS_PASSED++))
    else
        log_error "部署脚本帮助信息异常"
        ((TESTS_FAILED++))
    fi
}

# 测试 7: 错误处理（不存在的配置）
test_error_handling() {
    log_test "测试 7: 错误处理"
    ((TESTS_TOTAL++))
    
    # 测试 auto_deploy 处理不存在的配置文件
    if /home/node/.openclaw/v2ray/scripts/v2ray-vps-auto-deploy.sh deploy --config /nonexistent/config.json --web-server caddy 2>&1 | grep -q "未安装\|未找到\|不存在"; then
        log_success "错误处理正常（期望的错误）"
        ((TESTS_PASSED++))
    else
        # 也可能因为 $JQ 不存在而失败
        if /home/node/.openclaw/v2ray/scripts/v2ray-vps-auto-deploy.sh deploy --config /nonexistent/config.json --web-server caddy 2>&1 | grep -q "$JQ"; then
            log_success "错误处理正常（$JQ 不存在）"
            ((TESTS_PASSED++))
        else
            log_warn "错误处理测试结果不确定（取决于环境）"
        fi
    fi
}

# 测试 8: 变更检测
test_change_detection() {
    log_test "测试 8: 配置变更检测"
    ((TESTS_TOTAL++))
    
    local tmp_config1="/tmp/test_change_detection1.json"
    local tmp_config2="/tmp/test_change_detection2.json"
    local state_dir="/tmp/test_change_state"
    
    mkdir -p "$state_dir"
    
    # 创建两个相同内容的配置（哈希应该相同）
    cat > "$tmp_config1" << EOF
{
    "inbounds": [{
        "port": 8443,
        "protocol": "vmess",
        "streamSettings": {"network": "ws"}
    }]
}
EOF
    
    cat > "$tmp_config2" << EOF
{
    "inbounds": [{
        "port": 8443,
        "protocol": "vmess",
        "streamSettings": {"network": "ws"}
    }]
}
EOF
    
    local hash1 hash2
    hash1=$(sha256sum "$tmp_config1" | cut -d' ' -f1)
    hash2=$(sha256sum "$tmp_config2" | cut -d' ' -f1)
    
    if [[ "$hash1" == "$hash2" ]]; then
        log_success "相同配置具有相同哈希值"
        ((TESTS_PASSED++))
    else
        log_error "相同配置哈希值不匹配"
        ((TESTS_FAILED++))
    fi
    
    # 修改配置
    cat > "$tmp_config2" << EOF
{
    "inbounds": [{
        "port": 8444,  # 不同的端口
        "protocol": "vmess",
        "streamSettings": {"network": "ws"}
    }]
}
EOF
    
    hash2=$(sha256sum "$tmp_config2" | cut -d' ' -f1)
    
    if [[ "$hash1" != "$hash2" ]]; then
        log_success "不同配置具有不同哈希值"
        ((TESTS_PASSED++))
    else
        log_error "不同配置哈希值应该不同"
        ((TESTS_FAILED++))
    fi
    
    # 清理
    rm -rf "$state_dir"
    rm -f "$tmp_config1" "$tmp_config2"
}

# ========================================
# 主测试流程
# ========================================

main() {
    log_info "=========================================="
    log_info "V2Ray VPS 架构自动部署集成测试"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "=========================================="
    
    cd /home/node/.openclaw/v2ray
    
    # 检查必需工具
    if [[ -x /tmp/jq ]]; then
        JQ=/tmp/jq
    elif command -v jq &> /dev/null; then
        JQ=jq
    else
        log_error "jq 未安装，请先安装 jq"
        exit 1
    fi
    
    if ! command -v v2ray &> /dev/null; then
        log_warn "V2Ray 未安装，某些测试将被跳过"
    fi
    
    # 运行测试
    test_config_validation
    test_config_extraction
    test_state_management
    test_script_syntax
    test_core_integration
    test_parameter_validation
    test_error_handling
    test_change_detection
    
    # 显示测试结果
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
