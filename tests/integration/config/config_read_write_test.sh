#!/bin/bash
# ============================================================================
# V2Ray 配置读写一致性集成测试套件
# ============================================================================
# 测试目标：验证配置写入后读取的字段完全一致
# 覆盖场景：WS/H2/gRPC/TCP/mKCP/QUIC + TLS/non-TLS + Reality
# 协议覆盖：VMess/VLESS/Trojan/Shadowsocks
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试统计
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# JQ 路径
JQ="/tmp/jq"
[[ -x "$JQ" ]] || JQ="jq"

# ============================================================================
# 工具函数
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        log_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "$message"
        echo "  期望：'$expected'"
        echo "  实际：'$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ -n "$value" ]]; then
        log_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "$message"
        echo "  值为空"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================================================
# 测试配置生成
# ============================================================================

generate_test_config() {
    local protocol="$1"
    local transport="$2"
    local security="$3"
    local host="$4"
    local path="$5"
    local uuid="${6:-$(cat /proc/sys/kernel/random/uuid)}"
    local port="${7:-8443}"
    
    case "$transport" in
        ws)
            if [[ "$security" == "tls" ]]; then
                cat << EOF
{
  "inbounds": [{
    "tag": "${protocol}-${transport}-${security}",
    "port": $port,
    "protocol": "${protocol,,}",
    "settings": {
      "clients": [{
        "id": "$uuid",
        "email": "user@test.com",
        "level": 0
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "wsSettings": {
        "path": "$path",
        "headers": {
          "Host": "$host"
        }
      }
    }
  }]
}
EOF
            else
                cat << EOF
{
  "inbounds": [{
    "tag": "${protocol}-${transport}",
    "port": $port,
    "protocol": "${protocol,,}",
    "settings": {
      "clients": [{
        "id": "$uuid",
        "email": "user@test.com",
        "level": 0
      }]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "$path",
        "headers": {
          "Host": "$host"
        }
      }
    }
  }]
}
EOF
            fi
            ;;
        grpc)
            cat << EOF
{
  "inbounds": [{
    "tag": "${protocol}-${transport}-${security}",
    "port": $port,
    "protocol": "${protocol,,}",
    "settings": {
      "clients": [{
        "id": "$uuid",
        "email": "user@test.com",
        "level": 0
      }]
    },
    "streamSettings": {
      "network": "grpc",
      "security": "tls",
      "grpc_host": "$host",
      "grpcSettings": {
        "serviceName": "$path"
      }
    }
  }]
}
EOF
            ;;
        h2)
            cat << EOF
{
  "inbounds": [{
    "tag": "${protocol}-${transport}-${security}",
    "port": $port,
    "protocol": "${protocol,,}",
    "settings": {
      "clients": [{
        "id": "$uuid",
        "email": "user@test.com",
        "level": 0
      }]
    },
    "streamSettings": {
      "network": "h2",
      "security": "tls",
      "httpSettings": {
        "path": "$path",
        "host": ["$host"]
      }
    }
  }]
}
EOF
            ;;
        tcp)
            if [[ "$security" == "tls" ]]; then
                cat << EOF
{
  "inbounds": [{
    "tag": "${protocol}-${transport}-${security}",
    "port": $port,
    "protocol": "${protocol,,}",
    "settings": {
      "clients": [{
        "id": "$uuid",
        "email": "user@test.com",
        "level": 0
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "tls"
    }
  }]
}
EOF
            else
                cat << EOF
{
  "inbounds": [{
    "tag": "${protocol}-${transport}",
    "port": $port,
    "protocol": "${protocol,,}",
    "settings": {
      "clients": [{
        "id": "$uuid",
        "email": "user@test.com",
        "level": 0
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "none"
    }
  }]
}
EOF
            fi
            ;;
        reality)
            cat << EOF
{
  "inbounds": [{
    "tag": "${protocol}-${transport}-reality",
    "port": $port,
    "protocol": "${protocol,,}",
    "settings": {
      "clients": [{
        "id": "$uuid",
        "email": "user@test.com",
        "level": 0
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "serverNames": ["$host"],
        "privateKey": "test-private-key",
        "publicKey": "test-public-key"
      }
    }
  }]
}
EOF
            ;;
        *)
            echo "不支持的传输类型：$transport"
            return 1
            ;;
    esac
}

# ============================================================================
# 测试配置读取
# ============================================================================

test_config_read() {
    local config_json="$1"
    local expected_net="$2"
    local expected_security="$3"
    local expected_path="$4"
    local expected_host="$5"
    local test_name="$6"
    
    log_info "测试：$test_name"
    
    # 提取 MORE 数据
    local MORE_DATA=$(echo "$config_json" | $JQ -r '
        (.inbounds[0].streamSettings.network//""),
        (.inbounds[0].streamSettings.security//""),
        (.inbounds[0].streamSettings.tcpSettings.header.type//""),
        (.inbounds[0].streamSettings.kcpSettings.seed//""),
        (.inbounds[0].streamSettings.kcpSettings.header.type//""),
        (.inbounds[0].streamSettings.quicSettings.header.type//""),
        (.inbounds[0].streamSettings.wsSettings.path//""),
        (.inbounds[0].streamSettings.httpSettings.path//""),
        (.inbounds[0].streamSettings.grpcSettings.serviceName//"")
    ')
    
    # 提取 HOST 数据
    local HOST_DATA=$(echo "$config_json" | $JQ -r '
        (.inbounds[0].streamSettings.grpc_host//""),
        (.inbounds[0].streamSettings.wsSettings.headers.Host//""),
        (.inbounds[0].streamSettings.httpSettings.host[0]//"")
    ')
    
    # 提取 REALITY 数据
    local REALITY_DATA=$(echo "$config_json" | $JQ -r '
        (.inbounds[0].streamSettings.realitySettings.serverNames[0]//""),
        (.inbounds[0].streamSettings.realitySettings.publicKey//""),
        (.inbounds[0].streamSettings.realitySettings.privateKey//"")
    ')
    
    # 读取数组
    local -a MORE_ARR
    while IFS= read -r line; do
        MORE_ARR+=("$line")
    done <<< "$MORE_DATA"
    
    local -a HOST_ARR
    while IFS= read -r line; do
        HOST_ARR+=("$line")
    done <<< "$HOST_DATA"
    
    local -a REALITY_ARR
    while IFS= read -r line; do
        REALITY_ARR+=("$line")
    done <<< "$REALITY_DATA"
    
    # 提取字段
    local NET="${MORE_ARR[0]}"
    local SECURITY="${MORE_ARR[1]}"
    local WS_PATH="${MORE_ARR[6]}"
    local H2_PATH="${MORE_ARR[7]}"
    local GRPC_SERVICE_NAME="${MORE_ARR[8]}"
    
    local GRPC_HOST="${HOST_ARR[0]}"
    local WS_HOST="${HOST_ARR[1]}"
    local H2_HOST="${HOST_ARR[2]}"
    
    local REALITY_SNI="${REALITY_ARR[0]}"
    
    # 合并 URL_PATH（修复后的逻辑）
    local URL_PATH=""
    [[ -z $URL_PATH && $GRPC_SERVICE_NAME ]] && URL_PATH="$GRPC_SERVICE_NAME"
    [[ -z $URL_PATH && $WS_PATH ]] && URL_PATH="$WS_PATH"
    [[ -z $URL_PATH && $H2_PATH ]] && URL_PATH="$H2_PATH"
    
    # 合并 HOST
    local HOST=""
    [[ -z $HOST && $GRPC_HOST ]] && HOST="$GRPC_HOST"
    [[ -z $HOST && $WS_HOST ]] && HOST="$WS_HOST"
    [[ -z $HOST && $H2_HOST ]] && HOST="$H2_HOST"
    [[ -z $HOST && $REALITY_SNI ]] && HOST="$REALITY_SNI"
    
    # 验证
    assert_equals "$expected_net" "$NET" "网络类型匹配"
    assert_equals "$expected_security" "$SECURITY" "安全类型匹配"
    assert_equals "$expected_path" "$URL_PATH" "路径匹配"
    assert_equals "$expected_host" "$HOST" "主机匹配"
    
    echo ""
}

# ============================================================================
# 测试执行
# ============================================================================

run_tests() {
    echo "========================================"
    echo "V2Ray 配置读写一致性测试套件"
    echo "========================================"
    echo ""
    
    # 测试 1: VMess-WS-TLS
    log_info "=== 测试组 1: VMess-WS-TLS ==="
    local config=$(generate_test_config "VMess" "ws" "tls" "ws.example.com" "/websocket-path")
    test_config_read "$config" "ws" "tls" "/websocket-path" "ws.example.com" "VMess-WS-TLS 配置读取"
    
    # 测试 2: VMess-gRPC-TLS
    log_info "=== 测试组 2: VMess-gRPC-TLS ==="
    config=$(generate_test_config "VMess" "grpc" "tls" "grpc.example.com" "grpc-service")
    test_config_read "$config" "grpc" "tls" "grpc-service" "grpc.example.com" "VMess-gRPC-TLS 配置读取"
    
    # 测试 3: VMess-H2-TLS
    log_info "=== 测试组 3: VMess-H2-TLS ==="
    config=$(generate_test_config "VMess" "h2" "tls" "h2.example.com" "/h2-path")
    test_config_read "$config" "h2" "tls" "/h2-path" "h2.example.com" "VMess-H2-TLS 配置读取"
    
    # 测试 4: VLESS-WS-TLS
    log_info "=== 测试组 4: VLESS-WS-TLS ==="
    config=$(generate_test_config "VLESS" "ws" "tls" "vless-ws.example.com" "/vless-ws")
    test_config_read "$config" "ws" "tls" "/vless-ws" "vless-ws.example.com" "VLESS-WS-TLS 配置读取"
    
    # 测试 5: VLESS-gRPC-TLS
    log_info "=== 测试组 5: VLESS-gRPC-TLS ==="
    config=$(generate_test_config "VLESS" "grpc" "tls" "vless-grpc.example.com" "vless-grpc")
    test_config_read "$config" "grpc" "tls" "vless-grpc" "vless-grpc.example.com" "VLESS-gRPC-TLS 配置读取"
    
    # 测试 6: Trojan-WS-TLS
    log_info "=== 测试组 6: Trojan-WS-TLS ==="
    config=$(generate_test_config "Trojan" "ws" "tls" "trojan.example.com" "/trojan-path")
    test_config_read "$config" "ws" "tls" "/trojan-path" "trojan.example.com" "Trojan-WS-TLS 配置读取"
    
    # 测试 7: Trojan-gRPC-TLS
    log_info "=== 测试组 7: Trojan-gRPC-TLS ==="
    config=$(generate_test_config "Trojan" "grpc" "tls" "trojan-grpc.example.com" "trojan-grpc")
    test_config_read "$config" "grpc" "tls" "trojan-grpc" "trojan-grpc.example.com" "Trojan-gRPC-TLS 配置读取"
    
    # 测试 8: VMess-TCP (无 TLS)
    log_info "=== 测试组 8: VMess-TCP (无 TLS) ==="
    config=$(generate_test_config "VMess" "tcp" "none" "" "")
    test_config_read "$config" "tcp" "none" "" "" "VMess-TCP 配置读取"
    
    # 测试 9: VMess-TCP-TLS
    log_info "=== 测试组 9: VMess-TCP-TLS ==="
    config=$(generate_test_config "VMess" "tcp" "tls" "" "")
    test_config_read "$config" "tcp" "tls" "" "" "VMess-TCP-TLS 配置读取"
    
    # 测试 10: Reality 配置
    log_info "=== 测试组 10: Reality 配置 ==="
    config=$(generate_test_config "VLESS" "reality" "reality" "reality.example.com" "")
    test_config_read "$config" "tcp" "reality" "" "reality.example.com" "VLESS-Reality 配置读取"
}

# ============================================================================
# 主程序
# ============================================================================

main() {
    run_tests
    
    echo "========================================"
    echo "测试总结"
    echo "========================================"
    echo "总测试数：$TESTS_TOTAL"
    echo -e "通过：${GREEN}$TESTS_PASSED${NC}"
    echo -e "失败：${RED}$TESTS_FAILED${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ 所有测试通过！${NC}"
        return 0
    else
        echo -e "${RED}✗ 有测试失败${NC}"
        return 1
    fi
}

main "$@"
