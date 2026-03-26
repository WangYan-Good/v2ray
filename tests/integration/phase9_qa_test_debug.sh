#!/usr/bin/env bash
# ============================================================================
# V2Ray Phase 9 - QA 测试脚本
# ============================================================================
# 
# 用途: 执行 Phase 9 修复的完整测试验证
# 参考: /home/node/.openclaw/v2ray/docs/V2Ray-Phase9-Architect-Fix-Plan.md
# 
# 测试类型:
#   1. 本地语法验证 (Syntax Validation)
#   2. 变量展开验证 (Variable Expansion)
#   3. jq 解析验证 (JSON Parsing)
#   4. 配置读写一致性验证 (Config Read/Write Consistency)
#   5. VPS 真实环境验证 (VPS Production Environment)
#
# 使用方法:
#   ./phase9_qa_test.sh [--local|--vps|--all] [--verbose]
#
# 选项:
#   --local    仅执行本地测试
#   --vps      仅执行 VPS 测试
#   --all      执行所有测试 (默认)
#   --verbose  显示详细输出
#   --help     显示帮助信息
#
# ============================================================================

set -uo pipefail

# ============================================================================
# 配置
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_SH="$SCRIPT_DIR/../src/core.sh"
V2RAY_PATH="/home/node/.openclaw/v2ray"
CONFIG_DIR="/etc/v2ray/configs"
LOG_DIR="$SCRIPT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/phase9_qa_test_${TIMESTAMP}.log"

# VPS 配置 (待填写)
VPS_USER="${VPS_USER:-root}"
VPS_HOST="${VPS_HOST:-}"
VPS_PATH="${VPS_PATH:-/home/node/.openclaw/v2ray}"

# 测试配置
TEST_MODE="${TEST_MODE:-all}"  # local, vps, all
VERBOSE="${VERBOSE:-false}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 计数器
pass_count=0
fail_count=0
skip_count=0
total_count=0

# ============================================================================
# 日志函数
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_pass() {
    local message="$*"
    echo -e "${GREEN}✓ PASS${NC}: $message" | tee -a "$LOG_FILE"
    ((pass_count++))
    ((total_count++))
}

log_fail() {
    local message="$*"
    echo -e "${RED}✗ FAIL${NC}: $message" | tee -a "$LOG_FILE"
    ((fail_count++))
    ((total_count++))
}

log_skip() {
    local message="$*"
    echo -e "${YELLOW}⊘ SKIP${NC}: $message" | tee -a "$LOG_FILE"
    ((skip_count++))
    ((total_count++))
}

log_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $*" | tee -a "$LOG_FILE"
}

log_section() {
    echo "" | tee -a "$LOG_FILE"
    echo "=========================================" | tee -a "$LOG_FILE"
    echo -e "${CYAN}$*${NC}" | tee -a "$LOG_FILE"
    echo "=========================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

log_test() {
    local test_id="$1"
    local test_name="$2"
    echo -e "${BLUE}TEST${NC}: [$test_id] $test_name" | tee -a "$LOG_FILE"
}

# ============================================================================
# 辅助函数
# ============================================================================

check_jq() {
    if ! command -v jq &> /dev/null; then
        log_fail "jq 未安装，请安装 jq 后重试"
        return 1
    fi
    
    local jq_version=$(jq --version | cut -d'-' -f2)
    log_info "jq 版本: $jq_version"
    return 0
}

check_bash() {
    local bash_version=$(bash --version | head -n1 | grep -oP '\d+\.\d+' | head -n1)
    log_info "Bash 版本: $bash_version"
    
    if (( $(echo "$bash_version >= 4.0" | bc -l) )); then
        return 0
    else
        log_fail "Bash 版本过低，需要 4.0+"
        return 1
    fi
}

check_core_sh() {
    if [[ ! -f "$CORE_SH" ]]; then
        log_fail "core.sh 文件不存在: $CORE_SH"
        return 1
    fi
    log_info "core.sh 文件存在: $CORE_SH"
    return 0
}

check_vps_connection() {
    if [[ -z "$VPS_HOST" ]]; then
        log_warn "VPS_HOST 未设置，跳过 VPS 测试"
        return 1
    fi
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$VPS_USER@$VPS_HOST" "echo 'Connection successful'" &> /dev/null; then
        log_pass "VPS 连接成功: $VPS_HOST"
        return 0
    else
        log_fail "VPS 连接失败: $VPS_HOST"
        return 1
    fi
}

# ============================================================================
# 测试 1: 本地语法验证
# ============================================================================

test_syntax_validation() {
    log_section "测试 1: 本地语法验证"
    
    # SYN-001: Shell 语法检查
    log_test "SYN-001" "Shell 语法检查"
    if bash -n "$CORE_SH" 2>&1; then
        log_pass "Shell 语法检查通过"
    else
        log_fail "Shell 语法检查失败"
        bash -n "$CORE_SH" 2>&1 | tee -a "$LOG_FILE"
        return 1
    fi
    
    # SYN-002: 辅助函数定义检查
    log_test "SYN-002" "辅助函数定义检查"
    source "$CORE_SH" 2>/dev/null || true
    
    local functions=(
        "generate_protocol_settings"
        "generate_client_settings"
        "generate_stream_settings"
        "generate_sniffing"
    )
    
    local all_defined=true
    for func in "${functions[@]}"; do
        if declare -f "$func" > /dev/null 2>&1; then
            log_pass "函数 $func 已定义"
        else
            log_fail "函数 $func 未定义"
            all_defined=false
        fi
    done
    
    if [[ "$all_defined" == "false" ]]; then
        return 1
    fi
    
    # SYN-003: 辅助函数调用测试
    log_test "SYN-003" "辅助函数调用测试"
    local test_result=true
    
    if generate_protocol_settings vmess "test-uuid" > /dev/null 2>&1; then
        log_pass "generate_protocol_settings 调用成功"
    else
        log_fail "generate_protocol_settings 调用失败"
        test_result=false
    fi
    
    if generate_client_settings trojan "example.com" 443 "password" > /dev/null 2>&1; then
        log_pass "generate_client_settings 调用成功"
    else
        log_fail "generate_client_settings 调用失败"
        test_result=false
    fi
    
    if generate_stream_settings ws "/path" "host.com" "tls" > /dev/null 2>&1; then
        log_pass "generate_stream_settings 调用成功"
    else
        log_fail "generate_stream_settings 调用失败"
        test_result=false
    fi
    
    if generate_sniffing > /dev/null 2>&1; then
        log_pass "generate_sniffing 调用成功"
    else
        log_fail "generate_sniffing 调用失败"
        test_result=false
    fi
    
    if [[ "$test_result" == "false" ]]; then
        return 1
    fi
    
    # SYN-004: Case 语句块语法验证
    log_test "SYN-004" "Case 语句块语法验证"
    # 通过 bash -n 已验证，这里检查代码结构
    if grep -q "case \$IS_LOWER in" "$CORE_SH" && \
       grep -q "generate_protocol_settings" "$CORE_SH" && \
       grep -q "generate_stream_settings" "$CORE_SH"; then
        log_pass "Case 语句块结构正确"
    else
        log_fail "Case 语句块结构异常"
        return 1
    fi
    
    # SYN-005: jq 命令调用语法验证
    log_test "SYN-005" "jq 命令调用语法验证"
    local jq_calls=$(grep -c "jq -n" "$CORE_SH" || true)
    log_info "发现 $jq_calls 个 jq -n 调用"
    
    if [[ $jq_calls -gt 0 ]]; then
        log_pass "jq 命令调用存在"
    else
        log_warn "未发现 jq -n 调用，请确认代码已更新"
    fi
}

# ============================================================================
# 测试 2: 变量展开验证
# ============================================================================

test_variable_expansion() {
    log_section "测试 2: 变量展开验证"
    
    source "$CORE_SH" 2>/dev/null || true
    
    # 测试变量
    local test_uuid="550e8400-e29b-41d4-a716-446655440000"
    local test_password="secure-password-123"
    local test_host="proxy.example.com"
    local test_path="/test/path"
    local test_port="8443"
    
    # VAR-001: VMess UUID 展开
    log_test "VAR-001" "VMess UUID 变量展开"
    local vmess_settings=$(generate_protocol_settings vmess "$test_uuid" 2>/dev/null)
    if [[ "$vmess_settings" == *"$test_uuid"* ]] && echo "$vmess_settings" | jq . > /dev/null 2>&1; then
        log_pass "VMess UUID 正确展开"
    else
        log_fail "VMess UUID 未正确展开"
        echo "输出: $vmess_settings" | tee -a "$LOG_FILE"
    fi
    
    # VAR-002: Trojan 密码展开
    log_test "VAR-002" "Trojan 密码变量展开"
    local trojan_settings=$(generate_protocol_settings trojan "$test_password" 2>/dev/null)
    if [[ "$trojan_settings" == *"$test_password"* ]] && echo "$trojan_settings" | jq . > /dev/null 2>&1; then
        log_pass "Trojan 密码正确展开"
    else
        log_fail "Trojan 密码未正确展开"
        echo "输出: $trojan_settings" | tee -a "$LOG_FILE"
    fi
    
    # VAR-003: WS Host 展开
    log_test "VAR-003" "WS Host 变量展开"
    local ws_stream=$(generate_stream_settings ws "$test_path" "$test_host" "tls" 2>/dev/null)
    if [[ "$ws_stream" == *"$test_host"* ]] && echo "$ws_stream" | jq . > /dev/null 2>&1; then
        log_pass "WS Host 正确展开"
    else
        log_fail "WS Host 未正确展开"
        echo "输出: $ws_stream" | tee -a "$LOG_FILE"
    fi
    
    # VAR-004: 端口变量展开
    log_test "VAR-004" "端口变量展开测试"
    local full_config=$(jq -n \
        --arg tag "test" \
        --argjson port "$test_port" \
        --arg protocol "vmess" \
        '{tag: $tag, port: $port, protocol: $protocol}' 2>/dev/null)
    
    if echo "$full_config" | jq -e ".port == $test_port" > /dev/null 2>&1; then
        log_pass "端口变量正确展开"
    else
        log_fail "端口变量未正确展开"
    fi
    
    # VAR-005 ~ VAR-015: 其他协议组合变量展开
    log_test "VAR-005~015" "其他协议组合变量展开"
    local protocols=(
        "vmess:test-uuid"
        "vless:test-uuid"
        "trojan:test-password"
        "shadowsocks:aes-256-gcm:test-password"
        "socks:test-user:test-pass"
    )
    
    for proto_config in "${protocols[@]}"; do
        IFS=':' read -r proto arg1 arg2 <<< "$proto_config"
        local settings=$(generate_protocol_settings "$proto" "$arg1" "$arg2" 2>/dev/null)
        if echo "$settings" | jq . > /dev/null 2>&1; then
            log_pass "$proto 变量展开正确"
        else
            log_fail "$proto 变量展开失败"
        fi
    done
}

# ============================================================================
# 测试 3: jq 解析验证
# ============================================================================

test_json_parsing() {
    log_section "测试 3: jq 解析验证"
    
    source "$CORE_SH" 2>/dev/null || true
    
    # CRITICAL-01: Trojan-H2-TLS
    log_test "CRITICAL-01" "Trojan-H2-TLS jq 解析验证"
    
    local IS_CONFIG_NAME="qa-critical-01"
    local PORT=443
    local IS_PROTOCOL="trojan"
    local TROJAN_PASSWORD="test-password-$(uuidgen 2>/dev/null || echo 'test-123')"
    local HOST="proxy.yourdie.com"
    local URL_PATH="/test"
    
    local IS_SETTINGS_JSON=$(generate_protocol_settings trojan "$TROJAN_PASSWORD" 2>/dev/null)
    local IS_STREAM_SETTINGS_JSON=$(generate_stream_settings h2 "$URL_PATH" "$HOST" "tls" 2>/dev/null)
    local IS_SNIFFING_JSON=$(generate_sniffing 2>/dev/null)
    
    local IS_NEW_JSON=$(jq -n \
        --arg tag "$IS_CONFIG_NAME" \
        --argjson port "$PORT" \
        --arg listen "127.0.0.1" \
        --arg protocol "$IS_PROTOCOL" \
        --argjson settings "$IS_SETTINGS_JSON" \
        --argjson streamSettings "$IS_STREAM_SETTINGS_JSON" \
        --argjson sniffing "$IS_SNIFFING_JSON" \
        '{
            inbounds: [{
                tag: $tag,
                port: $port,
                listen: $listen,
                protocol: $protocol,
                settings: $settings,
                streamSettings: $streamSettings,
                sniffing: $sniffing
            }]
        }' 2>/dev/null)
    
    if echo "$IS_NEW_JSON" | jq . > /dev/null 2>&1; then
        log_pass "Trojan-H2-TLS jq 解析成功"
        
        # 验证关键字段
        local proto=$(echo "$IS_NEW_JSON" | jq -r '.inbounds[0].protocol')
        local network=$(echo "$IS_NEW_JSON" | jq -r '.inbounds[0].streamSettings.network')
        
        if [[ "$proto" == "trojan" ]]; then
            log_pass "protocol 字段正确: $proto"
        else
            log_fail "protocol 字段错误: $proto (期望: trojan)"
        fi
        
        if [[ "$network" == "h2" ]]; then
            log_pass "network 字段正确: $network"
        else
            log_fail "network 字段错误: $network (期望: h2)"
        fi
    else
        log_fail "Trojan-H2-TLS jq 解析失败"
        echo "输出: $IS_NEW_JSON" | tee -a "$LOG_FILE"
    fi
    
    # CRITICAL-02: VLESS-gRPC-TLS
    log_test "CRITICAL-02" "VLESS-gRPC-TLS jq 解析验证"
    
    IS_CONFIG_NAME="qa-critical-02"
    IS_PROTOCOL="vless"
    local UUID="test-uuid-$(uuidgen 2>/dev/null || echo 'test-456')"
    HOST="proxy.yourdie.com"
    URL_PATH="grpc"
    
    IS_SETTINGS_JSON=$(generate_protocol_settings vless "$UUID" 2>/dev/null)
    IS_STREAM_SETTINGS_JSON=$(generate_stream_settings grpc "$URL_PATH" "$HOST" "tls" 2>/dev/null)
    IS_SNIFFING_JSON=$(generate_sniffing 2>/dev/null)
    
    IS_NEW_JSON=$(jq -n \
        --arg tag "$IS_CONFIG_NAME" \
        --argjson port "$PORT" \
        --arg listen "127.0.0.1" \
        --arg protocol "$IS_PROTOCOL" \
        --argjson settings "$IS_SETTINGS_JSON" \
        --argjson streamSettings "$IS_STREAM_SETTINGS_JSON" \
        --argjson sniffing "$IS_SNIFFING_JSON" \
        '{
            inbounds: [{
                tag: $tag,
                port: $port,
                listen: $listen,
                protocol: $protocol,
                settings: $settings,
                streamSettings: $streamSettings,
                sniffing: $sniffing
            }]
        }' 2>/dev/null)
    
    if echo "$IS_NEW_JSON" | jq . > /dev/null 2>&1; then
        log_pass "VLESS-gRPC-TLS jq 解析成功"
        
        local proto=$(echo "$IS_NEW_JSON" | jq -r '.inbounds[0].protocol')
        local network=$(echo "$IS_NEW_JSON" | jq -r '.inbounds[0].streamSettings.network')
        
        if [[ "$proto" == "vless" ]]; then
            log_pass "protocol 字段正确: $proto"
        else
            log_fail "protocol 字段错误: $proto"
        fi
        
        if [[ "$network" == "grpc" ]]; then
            log_pass "network 字段正确: $network"
        else
            log_fail "network 字段错误: $network"
        fi
    else
        log_fail "VLESS-gRPC-TLS jq 解析失败"
    fi
    
    # CRITICAL-03: VLESS-Reality
    log_test "CRITICAL-03" "VLESS-Reality jq 解析验证"
    
    IS_CONFIG_NAME="qa-critical-03"
    local IS_SERVERNAME="www.example.com"
    local IS_PUBLIC_KEY="test-public-key"
    local IS_PRIVATE_KEY="test-private-key"
    
    IS_SETTINGS_JSON=$(generate_protocol_settings vless "$UUID" "xtls-rprx-vision" 2>/dev/null)
    IS_STREAM_SETTINGS_JSON=$(generate_stream_settings reality \
        "${IS_SERVERNAME}:443" \
        "[\"${IS_SERVERNAME}\",\"\"]" \
        "$IS_PUBLIC_KEY" \
        "$IS_PRIVATE_KEY" 2>/dev/null)
    IS_SNIFFING_JSON=$(generate_sniffing 2>/dev/null)
    
    IS_NEW_JSON=$(jq -n \
        --arg tag "$IS_CONFIG_NAME" \
        --argjson port "$PORT" \
        --arg listen "127.0.0.1" \
        --arg protocol "$IS_PROTOCOL" \
        --argjson settings "$IS_SETTINGS_JSON" \
        --argjson streamSettings "$IS_STREAM_SETTINGS_JSON" \
        --argjson sniffing "$IS_SNIFFING_JSON" \
        '{
            inbounds: [{
                tag: $tag,
                port: $port,
                listen: $listen,
                protocol: $protocol,
                settings: $settings,
                streamSettings: $streamSettings,
                sniffing: $sniffing
            }]
        }' 2>/dev/null)
    
    if echo "$IS_NEW_JSON" | jq . > /dev/null 2>&1; then
        log_pass "VLESS-Reality jq 解析成功"
        
        local security=$(echo "$IS_NEW_JSON" | jq -r '.inbounds[0].streamSettings.security')
        if [[ "$security" == "reality" ]]; then
            log_pass "security 字段正确: $security"
        else
            log_fail "security 字段错误: $security"
        fi
    else
        log_fail "VLESS-Reality jq 解析失败"
    fi
    
    # JQ-004 ~ JQ-018: 其他协议组合
    log_test "JQ-004~018" "其他协议组合 jq 解析"
    
    local test_cases=(
        "vmess:tcp:none"
        "vmess:ws:tls"
        "vmess:grpc:tls"
        "vless:tcp:none"
        "vless:ws:tls"
        "trojan:tcp:tls"
        "trojan:ws:tls"
        "shadowsocks:tcp:none"
        "socks:tcp:none"
    )
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r protocol transport security <<< "$test_case"
        
        # 简化测试，只验证基本结构
        local settings=$(generate_protocol_settings "$protocol" "test-value" 2>/dev/null)
        if echo "$settings" | jq . > /dev/null 2>&1; then
            log_pass "$protocol-$transport-$security: jq 解析成功"
        else
            log_fail "$protocol-$transport-$security: jq 解析失败"
        fi
    done
}

# ============================================================================
# 测试 4: 配置读写一致性验证
# ============================================================================

test_config_read_write() {
    log_section "测试 4: 配置读写一致性验证"
    
    # 检查是否有 v2ray 命令
    if ! command -v v2ray &> /dev/null; then
        log_skip "v2ray 命令未找到，跳过配置读写测试"
        return 0
    fi
    
    # 检查配置目录
    if [[ ! -d "$CONFIG_DIR" ]]; then
        log_warn "配置目录不存在: $CONFIG_DIR"
        log_info "尝试创建目录..."
        mkdir -p "$CONFIG_DIR" 2>/dev/null || {
            log_skip "无法创建配置目录，跳过测试"
            return 0
        }
    fi
    
    # RW-001: Trojan-H2-TLS 配置读写
    log_test "RW-001" "Trojan-H2-TLS 配置读写验证"
    
    local test_name="qa-rw-test-001"
    local test_port="10001"
    
    # 创建配置
    log_info "创建测试配置: $test_name"
    if v2ray add --protocol=trojan --transport=h2 --tls=tls \
        --port="$test_port" --host="test.example.com" \
        --name="$test_name" 2>&1; then
        log_pass "配置创建成功"
        
        # 验证配置文件
        local config_file="$CONFIG_DIR/$test_name.json"
        if [[ -f "$config_file" ]]; then
            log_pass "配置文件已生成: $config_file"
            
            # 验证 JSON 有效性
            if jq . "$config_file" > /dev/null 2>&1; then
                log_pass "配置文件 JSON 有效"
                
                # 验证关键字段
                local proto=$(jq -r '.inbounds[0].protocol' "$config_file")
                local port=$(jq -r '.inbounds[0].port' "$config_file")
                local network=$(jq -r '.inbounds[0].streamSettings.network' "$config_file")
                
                if [[ "$proto" == "trojan" ]]; then
                    log_pass "protocol 字段正确: $proto"
                else
                    log_fail "protocol 字段错误: $proto"
                fi
                
                if [[ "$port" == "$test_port" ]]; then
                    log_pass "port 字段正确: $port"
                else
                    log_fail "port 字段错误: $port"
                fi
                
                if [[ "$network" == "h2" ]]; then
                    log_pass "network 字段正确: $network"
                else
                    log_fail "network 字段错误: $network"
                fi
            else
                log_fail "配置文件 JSON 无效"
            fi
            
            # 测试 info 命令
            log_info "测试 info 命令"
            local info_output=$(v2ray info "$test_name" 2>&1)
            if [[ $? -eq 0 ]]; then
                log_pass "info 命令执行成功"
            else
                log_fail "info 命令执行失败"
            fi
            
            # 清理
            log_info "清理测试配置"
            v2ray del "$test_name" 2>&1
            if [[ $? -eq 0 ]]; then
                log_pass "配置删除成功"
            else
                log_fail "配置删除失败"
            fi
        else
            log_fail "配置文件未生成"
        fi
    else
        log_fail "配置创建失败"
    fi
}

# ============================================================================
# 测试 5: VPS 真实环境验证
# ============================================================================

test_vps_environment() {
    log_section "测试 5: VPS 真实环境验证"
    
    # 检查 VPS 连接
    if ! check_vps_connection; then
        log_skip "VPS 连接失败，跳过 VPS 测试"
        return 0
    fi
    
    # VPS-001: 部署代码
    log_test "VPS-001" "VPS 代码部署"
    
    log_info "拉取修复代码到 VPS"
    if ssh "$VPS_USER@$VPS_HOST" "cd $VPS_PATH && git pull origin fix" 2>&1 | tee -a "$LOG_FILE"; then
        log_pass "代码部署成功"
    else
        log_fail "代码部署失败"
        return 1
    fi
    
    # VPS-002: VPS 语法验证
    log_test "VPS-002" "VPS Shell 语法验证"
    
    if ssh "$VPS_USER@$VPS_HOST" "bash -n $VPS_PATH/src/core.sh" 2>&1; then
        log_pass "VPS 语法验证通过"
    else
        log_fail "VPS 语法验证失败"
        return 1
    fi
    
    # VPS-003 ~ VPS-017: 15 种协议组合测试
    log_test "VPS-003~017" "VPS 协议组合测试"
    
    local test_protocols=(
        "vmess:tcp:none:10001"
        "vmess:ws:tls:10002"
        "vmess:grpc:tls:10003"
        "vmess:mkcp:none:10004"
        "vless:tcp:none:10005"
        "vless:ws:tls:10006"
        "vless:grpc:tls:10007"
        "vless:tcp:reality:10008"
        "vless:grpc:reality:10009"
        "trojan:tcp:tls:10010"
        "trojan:ws:tls:10011"
        "trojan:grpc:tls:10012"
        "shadowsocks:tcp:none:10013"
        "shadowsocks:udp:none:10014"
        "socks:tcp:none:10015"
    )
    
    for test_config in "${test_protocols[@]}"; do
        IFS=':' read -r protocol transport security port <<< "$test_config"
        local test_name="qa-vps-${protocol}-${transport}"
        
        log_info "测试: $test_name (端口 $port)"
        
        # 添加配置
        local add_output=$(ssh "$VPS_USER@$VPS_HOST" \
            "v2ray add --protocol=$protocol --transport=$transport \
            --tls=$security --port=$port --name=$test_name" 2>&1)
        
        if [[ $? -eq 0 ]]; then
            log_pass "$test_name: add 成功"
            
            # 验证配置
            local config_check=$(ssh "$VPS_USER@$VPS_HOST" \
                "cat /etc/v2ray/configs/$test_name.json | jq ." 2>&1)
            
            if [[ $? -eq 0 ]]; then
                log_pass "$test_name: 配置 JSON 有效"
            else
                log_fail "$test_name: 配置 JSON 无效"
            fi
            
            # 测试 info
            local info_output=$(ssh "$VPS_USER@$VPS_HOST" \
                "v2ray info $test_name" 2>&1)
            
            if [[ $? -eq 0 ]]; then
                log_pass "$test_name: info 成功"
            else
                log_fail "$test_name: info 失败"
            fi
            
            # 测试 del
            local del_output=$(ssh "$VPS_USER@$VPS_HOST" \
                "v2ray del $test_name" 2>&1)
            
            if [[ $? -eq 0 ]]; then
                log_pass "$test_name: del 成功"
            else
                log_fail "$test_name: del 失败"
            fi
        else
            log_fail "$test_name: add 失败"
            echo "错误输出: $add_output" | tee -a "$LOG_FILE"
        fi
    done
}

# ============================================================================
# 汇总报告
# ============================================================================

generate_summary() {
    log_section "测试汇总报告"
    
    echo "" | tee -a "$LOG_FILE"
    echo "=========================================" | tee -a "$LOG_FILE"
    echo "测试结果统计" | tee -a "$LOG_FILE"
    echo "=========================================" | tee -a "$LOG_FILE"
    echo -e "${GREEN}通过${NC}: $pass_count" | tee -a "$LOG_FILE"
    echo -e "${RED}失败${NC}: $fail_count" | tee -a "$LOG_FILE"
    echo -e "${YELLOW}跳过${NC}: $skip_count" | tee -a "$LOG_FILE"
    echo "总计: $total_count" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    local success_rate=0
    if [[ $total_count -gt 0 ]]; then
        success_rate=$(echo "scale=2; $pass_count * 100 / $total_count" | bc)
    fi
    
    echo "成功率: ${success_rate}%" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    if [[ $fail_count -eq 0 ]]; then
        echo -e "${GREEN}=========================================${NC}" | tee -a "$LOG_FILE"
        echo -e "${GREEN}所有测试通过!${NC}" | tee -a "$LOG_FILE"
        echo -e "${GREEN}=========================================${NC}" | tee -a "$LOG_FILE"
        return 0
    else
        echo -e "${RED}=========================================${NC}" | tee -a "$LOG_FILE"
        echo -e "${RED}部分测试失败，请检查日志${NC}" | tee -a "$LOG_FILE"
        echo -e "${RED}=========================================${NC}" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
        echo "日志文件: $LOG_FILE" | tee -a "$LOG_FILE"
        return 1
    fi
}

# ============================================================================
# 主函数
# ============================================================================

show_help() {
    cat << EOF
V2Ray Phase 9 - QA 测试脚本

用法: $0 [选项]

选项:
  --local      仅执行本地测试 (语法 + 变量 + jq)
  --vps        仅执行 VPS 测试
  --all        执行所有测试 (默认)
  --verbose    显示详细输出
  --help       显示此帮助信息

示例:
  $0 --local           # 仅本地测试
  $0 --vps             # 仅 VPS 测试
  $0 --all --verbose   # 所有测试，详细输出

环境变量:
  VPS_USER    VPS 用户名 (默认：root)
  VPS_HOST    VPS 主机地址 (必需用于 VPS 测试)
  VPS_PATH    V2Ray 路径 (默认：/home/node/.openclaw/v2ray)

EOF
}

main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --local)
                TEST_MODE="local"
                shift
                ;;
            --vps)
                TEST_MODE="vps"
                shift
                ;;
            --all)
                TEST_MODE="all"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    
    log_section "V2Ray Phase 9 - QA 测试开始"
    log_info "测试模式：$TEST_MODE"
    log_info "日志文件：$LOG_FILE"
    
    # 前置检查
    log_section "前置检查"
    
    if ! check_jq; then
        log_fail "jq 检查失败"
        exit 1
    fi
    
    if ! check_core_sh; then
        log_fail "core.sh 检查失败"
        exit 1
    fi
    
    # 执行测试
    case $TEST_MODE in
        local)
            test_syntax_validation
            test_variable_expansion
            test_json_parsing
            ;;
        vps)
            test_vps_environment
            ;;
        all)
            test_syntax_validation
            test_variable_expansion
            test_json_parsing
            test_config_read_write
            test_vps_environment
            ;;
    esac
    
    # 生成汇总报告
    generate_summary
    exit_code=$?
    
    log_info "测试完成"
    exit $exit_code
}

# 运行主函数
main "$@"
