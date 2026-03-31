#!/bin/bash
# ============================================================================
# V2Ray 边界情况与错误处理测试套件
# ============================================================================
# 测试目标：验证边界情况和错误处理
# 覆盖场景：空值、特殊字符、超长路径、无效配置等
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试统计
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# JQ 路径
JQ="/tmp/jq"
[[ -x "$JQ" ]] || JQ="jq"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }

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

assert_empty() {
    local value="$1"
    local message="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if [[ -z "$value" ]]; then
        log_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "$message (期望空值，实际：'$value')"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================================================
# 边界情况测试
# ============================================================================

test_empty_path() {
    log_info "=== 测试：空路径处理 ==="
    
    local config='{
      "inbounds": [{
        "streamSettings": {
          "network": "ws",
          "security": "tls",
          "wsSettings": {
            "path": "",
            "headers": {"Host": "example.com"}
          }
        }
      }]
    }'
    
    local path=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.wsSettings.path//""')
    assert_empty "$path" "空路径应返回空字符串"
}

test_special_chars_path() {
    log_info "=== 测试：特殊字符路径 ==="
    
    local config='{
      "inbounds": [{
        "streamSettings": {
          "network": "ws",
          "security": "tls",
          "wsSettings": {
            "path": "/api/v1/test-path_with.special",
            "headers": {"Host": "example.com"}
          }
        }
      }]
    }'
    
    local path=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.wsSettings.path//""')
    assert_equals "/api/v1/test-path_with.special" "$path" "特殊字符路径应正确解析"
}

test_long_path() {
    log_info "=== 测试：超长路径 ==="
    
    local long_path="/$(printf 'a%.0s' {1..200})"
    local config="{
      \"inbounds\": [{
        \"streamSettings\": {
          \"network\": \"ws\",
          \"security\": \"tls\",
          \"wsSettings\": {
            \"path\": \"$long_path\",
            \"headers\": {\"Host\": \"example.com\"}
          }
        }
      }]
    }"
    
    local path=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.wsSettings.path//""')
    assert_equals "$long_path" "$path" "超长路径应正确解析"
}

test_subdomain_host() {
    log_info "=== 测试：子域名主机 ==="
    
    local config='{
      "inbounds": [{
        "streamSettings": {
          "network": "ws",
          "security": "tls",
          "wsSettings": {
            "path": "/test",
            "headers": {"Host": "sub.domain.example.com"}
          }
        }
      }]
    }'
    
    local host=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.wsSettings.headers.Host//""')
    assert_equals "sub.domain.example.com" "$host" "子域名应正确解析"
}

test_grpc_empty_service() {
    log_info "=== 测试：gRPC 空服务名 ==="
    
    local config='{
      "inbounds": [{
        "streamSettings": {
          "network": "grpc",
          "security": "tls",
          "grpc_host": "grpc.example.com",
          "grpcSettings": {
            "serviceName": ""
          }
        }
      }]
    }'
    
    local service=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.grpcSettings.serviceName//""')
    assert_empty "$service" "空服务名应返回空字符串"
}

test_h2_host_array() {
    log_info "=== 测试：H2 主机数组 ==="
    
    local config='{
      "inbounds": [{
        "streamSettings": {
          "network": "h2",
          "security": "tls",
          "httpSettings": {
            "path": "/h2",
            "host": ["host1.example.com", "host2.example.com"]
          }
        }
      }]
    }'
    
    local host=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.httpSettings.host[0]//""')
    assert_equals "host1.example.com" "$host" "H2 主机数组第一个元素应正确解析"
}

test_missing_fields() {
    log_info "=== 测试：缺失字段处理 ==="
    
    local config='{
      "inbounds": [{
        "streamSettings": {
          "network": "tcp"
        }
      }]
    }'
    
    local network=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.network//""')
    local security=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.security//""')
    local ws_path=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.wsSettings.path//""')
    
    assert_equals "tcp" "$network" "network 字段应正确解析"
    assert_empty "$security" "缺失的 security 字段应返回空"
    assert_empty "$ws_path" "缺失的 wsSettings.path 字段应返回空"
}

test_unicode_path() {
    log_info "=== 测试：Unicode 路径 ==="
    
    local config='{
      "inbounds": [{
        "streamSettings": {
          "network": "ws",
          "security": "tls",
          "wsSettings": {
            "path": "/测试路径/test",
            "headers": {"Host": "example.com"}
          }
        }
      }]
    }'
    
    local path=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.wsSettings.path//""')
    assert_equals "/测试路径/test" "$path" "Unicode 路径应正确解析"
}

test_url_path_merge_priority() {
    log_info "=== 测试：URL_PATH 合并优先级 ==="
    
    # 测试 gRPC 优先
    local config_grpc='{
      "inbounds": [{
        "streamSettings": {
          "network": "grpc",
          "grpcSettings": {"serviceName": "grpc-service"},
          "wsSettings": {"path": "/ws-path"},
          "httpSettings": {"path": "/h2-path"}
        }
      }]
    }'
    
    local grpc_service=$(echo "$config_grpc" | $JQ -r '.inbounds[0].streamSettings.grpcSettings.serviceName//""')
    local ws_path=$(echo "$config_grpc" | $JQ -r '.inbounds[0].streamSettings.wsSettings.path//""')
    local h2_path=$(echo "$config_grpc" | $JQ -r '.inbounds[0].streamSettings.httpSettings.path//""')
    
    # 模拟 URL_PATH 合并逻辑
    local URL_PATH=""
    [[ -z $URL_PATH && $grpc_service ]] && URL_PATH="$grpc_service"
    [[ -z $URL_PATH && $ws_path ]] && URL_PATH="$ws_path"
    [[ -z $URL_PATH && $h2_path ]] && URL_PATH="$h2_path"
    
    assert_equals "grpc-service" "$URL_PATH" "gRPC 服务名应有最高优先级"
    
    # 测试 WS 优先（无 gRPC）
    local config_ws='{
      "inbounds": [{
        "streamSettings": {
          "network": "ws",
          "wsSettings": {"path": "/ws-path"},
          "httpSettings": {"path": "/h2-path"}
        }
      }]
    }'
    
    grpc_service=$(echo "$config_ws" | $JQ -r '.inbounds[0].streamSettings.grpcSettings.serviceName//""')
    ws_path=$(echo "$config_ws" | $JQ -r '.inbounds[0].streamSettings.wsSettings.path//""')
    h2_path=$(echo "$config_ws" | $JQ -r '.inbounds[0].streamSettings.httpSettings.path//""')
    
    URL_PATH=""
    [[ -z $URL_PATH && $grpc_service ]] && URL_PATH="$grpc_service"
    [[ -z $URL_PATH && $ws_path ]] && URL_PATH="$ws_path"
    [[ -z $URL_PATH && $h2_path ]] && URL_PATH="$h2_path"
    
    assert_equals "/ws-path" "$URL_PATH" "WS 路径应在无 gRPC 时优先"
}

test_host_merge_priority() {
    log_info "=== 测试：HOST 合并优先级 ==="
    
    local config='{
      "inbounds": [{
        "streamSettings": {
          "grpc_host": "grpc.example.com",
          "wsSettings": {"headers": {"Host": "ws.example.com"}},
          "httpSettings": {"host": ["h2.example.com"]}
        }
      }]
    }'
    
    local grpc_host=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.grpc_host//""')
    local ws_host=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.wsSettings.headers.Host//""')
    local h2_host=$(echo "$config" | $JQ -r '.inbounds[0].streamSettings.httpSettings.host[0]//""')
    
    # 模拟 HOST 合并逻辑
    local HOST=""
    [[ -z $HOST && $grpc_host ]] && HOST="$grpc_host"
    [[ -z $HOST && $ws_host ]] && HOST="$ws_host"
    [[ -z $HOST && $h2_host ]] && HOST="$h2_host"
    
    assert_equals "grpc.example.com" "$HOST" "gRPC host 应有最高优先级"
}

# ============================================================================
# 主程序
# ============================================================================

main() {
    echo "========================================"
    echo "V2Ray 边界情况与错误处理测试套件"
    echo "========================================"
    echo ""
    
    test_empty_path
    test_special_chars_path
    test_long_path
    test_subdomain_host
    test_grpc_empty_service
    test_h2_host_array
    test_missing_fields
    test_unicode_path
    test_url_path_merge_priority
    test_host_merge_priority
    
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
