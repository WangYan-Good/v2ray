#!/bin/bash
# v2ray-vps-auto-deploy.sh - V2Ray VPS 架构自动部署脚本
# 用于自动配置 TLS 终止代理（Caddy 或 Nginx）并设置反向代理规则
# 支持配置变更检测、自动部署、错误处理和静默模式

set -e

# ========================================
# 全局配置和变量定义
# ========================================

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V2RAY_DIR="${SCRIPT_DIR}/.."

# 默认参数
SILENT_MODE=false
LOG_LEVEL="info"  # debug, info, warn, error
V2RAY_CONFIG=""
WEB_SERVER=""  # caddy 或 nginx
DOMAIN=""
PORT=""
UUID=""
PASSWORD=""
PROTOCOL=""
SECURITY=""
SERVER_NAME=""
SSL_CERT_PATH=""
SSL_KEY_PATH=""
FORCE_DEPLOY=false

# 状态文件
STATE_FILE="/var/lib/v2ray-webproxy/state.json"
V2RAY_STATE_DIR="/var/lib/v2ray-webproxy"

# 颜色输出
RED='\e[31m'
GREEN='\e[92m'
YELLOW='\e[93m'
BLUE='\e[94m'
NONE='\e[0m'

# ========================================
# 日志函数
# ========================================

log_debug() {
    if [[ "$LOG_LEVEL" == "debug" ]]; then
        echo -e "${BLUE}[DEBUG]${NONE} $*" >&2
    fi
}

log_info() {
    if [[ "$LOG_LEVEL" != "error" ]]; then
        echo -e "${GREEN}[INFO]${NONE} $*"
    fi
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NONE} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NONE} $*" >&2
}

# ========================================
# 帮助信息
# ========================================

show_help() {
    cat << EOF
V2Ray VPS 架构自动部署脚本

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    deploy      部署 V2Ray VPS 架构
    cleanup     清理 V2Ray VPS 架构
    validate    验证配置
    status      显示状态
    help        显示此帮助信息

Options for 'deploy' command:
    --config FILE           V2Ray 配置文件路径
    --web-server SERVER     Web 服务器类型 (caddy 或 nginx)
    --domain DOMAIN         域名
    --port PORT             端口
    --uuid UUID             UUID (用于 VMess/VLESS)
    --password PASSWORD     密码 (用于 Trojan/Shadowsocks)
    --server-name NAME      SNI 服务器名称 (用于 REALITY)
    --ssl-cert PATH         SSL 证书路径 (Nginx)
    --ssl-key PATH          SSL 密钥路径 (Nginx)
    --force                 强制部署 (跳过变更检测)
    --silent                静默模式 (仅显示错误)
    --log-level LEVEL       日志级别 (debug, info, warn, error)

Options for 'cleanup' command:
    --config FILE           V2Ray 配置文件路径
    --web-server SERVER     Web 服务器类型 (caddy 或 nginx)

Examples:
    $0 deploy --config /etc/v2ray/config.json --web-server caddy --domain example.com
    $0 deploy --config /etc/v2ray/config.json --web-server nginx --domain example.com --ssl-cert /etc/ssl/cert.pem --ssl-key /etc/ssl/key.pem
    $0 cleanup --config /etc/v2ray/config.json --web-server caddy --domain example.com

EOF
}

# ========================================
# 参数解析
# ========================================

parse_args() {
    local command="$1"
    shift || true
    
    case "$command" in
        deploy|cleanup|validate|status)
            COMMAND="$command"
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        "")
            log_error "未指定命令"
            show_help
            exit 1
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                V2RAY_CONFIG="$2"
                shift 2
                ;;
            --web-server)
                WEB_SERVER="$2"
                shift 2
                ;;
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --port)
                PORT="$2"
                shift 2
                ;;
            --uuid)
                UUID="$2"
                shift 2
                ;;
            --password)
                PASSWORD="$2"
                shift 2
                ;;
            --server-name)
                SERVER_NAME="$2"
                shift 2
                ;;
            --ssl-cert)
                SSL_CERT_PATH="$2"
                shift 2
                ;;
            --ssl-key)
                SSL_KEY_PATH="$2"
                shift 2
                ;;
            --force)
                FORCE_DEPLOY=true
                shift
                ;;
            --silent)
                SILENT_MODE=true
                LOG_LEVEL="error"
                shift
                ;;
            --log-level)
                LOG_LEVEL="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ========================================
# 依赖检查函数
# ========================================

check_dependencies() {
    log_info "检查系统依赖..."
    
    # 检查 jq
    if ! command -v jq &> /dev/null; then
        log_error "jq 工具未安装"
        echo "请安装 jq:"
        echo "  Ubuntu/Debian: sudo apt install jq"
        echo "  CentOS/RHEL: sudo yum install jq"
        echo "  macOS: brew install jq"
        return 1
    fi
    
    # 检查 jq 版本（至少 1.6）
    local jq_version
    jq_version=$(jq --version 2>&1 | sed 's/jq-\([0-9.]*\).*/\1/')
    log_info "jq 版本: $jq_version"
    
    # 检查 V2Ray
    if command -v v2ray &> /dev/null; then
        local v2ray_version
        v2ray_version=$(v2ray --version 2>&1 | head -n1 | awk '{print $2}')
        log_info "V2Ray 版本: $v2ray_version"
    else
        log_warn "V2Ray 未安装，跳过版本检查"
    fi
    
    # 检查 Web 服务器
    if [[ "$WEB_SERVER" == "caddy" ]]; then
        if ! command -v caddy &> /dev/null; then
            log_error "Caddy 未安装"
            return 1
        fi
        local caddy_version
        caddy_version=$(caddy version 2>&1 | head -n1)
        log_info "Caddy 版本: $caddy_version"
    elif [[ "$WEB_SERVER" == "nginx" ]]; then
        if ! command -v nginx &> /dev/null; then
            log_error "Nginx 未安装"
            return 1
        fi
        local nginx_version
        nginx_version=$(nginx -v 2>&1 | sed 's/nginx version: nginx\///')
        log_info "Nginx 版本: $nginx_version"
    elif [[ -n "$WEB_SERVER" ]]; then
        log_error "未知的 Web 服务器类型: $WEB_SERVER"
        return 1
    fi
    
    log_info "所有依赖检查通过"
    return 0
}

# ========================================
# V2Ray 配置验证
# ========================================

validate_v2ray_config() {
    local config_file="$1"
    
    log_info "验证 V2Ray 配置文件: $config_file"
    
    # 检查文件存在
    if [[ ! -f "$config_file" ]]; then
        log_error "V2Ray 配置文件不存在: $config_file"
        return 1
    fi
    
    # 检查文件是否为有效的 JSON
    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "V2Ray 配置文件不是有效的 JSON格式: $config_file"
        return 1
    fi
    
    # 验证 V2Ray 配置语法
    if command -v v2ray &> /dev/null; then
        log_info "运行 V2Ray 配置语法验证..."
        if ! v2ray -test -config "$config_file" &> /dev/null; then
            log_error "V2Ray 配置语法验证失败"
            v2ray -test -config "$config_file" 2>&1 | while read -r line; do
                log_error "  $line"
            done
            return 1
        fi
        log_info "V2Ray 配置语法验证通过"
    else
        log_warn "V2Ray 未安装，跳过语法验证"
    fi
    
    return 0
}

# ========================================
# 从 V2Ray 配置中提取信息
# ========================================

extract_v2ray_config() {
    local config_file="$1"
    
    log_info "从 V2Ray 配置中提取信息..."
    
    # 提取 inbound 信息
    local inbound_port
    inbound_port=$(jq -r '.inbounds[0].port // ""' "$config_file")
    
    local protocol
    protocol=$(jq -r '.inbounds[0].protocol // ""' "$config_file")
    
    local network
    network=$(jq -r '.inbounds[0].streamSettings.network // .inbounds[0].settings.network // ""' "$config_file")
    
    local security
    security=$(jq -r '.inbounds[0].streamSettings.security // .inbounds[0].settings.security // ""' "$config_file")
    
    # 提取协议特定信息
    local uuid=""
    local password=""
    
    if [[ "$protocol" == "vmess" ]] || [[ "$protocol" == "vless" ]]; then
        uuid=$(jq -r '.inbounds[0].settings.clients[0].id // ""' "$config_file")
    elif [[ "$protocol" == "trojan" ]] || [[ "$protocol" == "shadowsocks" ]]; then
        password=$(jq -r '.inbounds[0].settings.clients[0].password // .inbounds[0].settings.password // ""' "$config_file")
    fi
    
    # 提取 host（用于 TLS）
    local host=""
    case "$network" in
        ws)
            host=$(jq -r '.inbounds[0].streamSettings.wsSettings.headers.Host // .inbounds[0].settings.wsSettings.headers.Host // ""' "$config_file")
            ;;
        h2)
            host=$(jq -r '.inbounds[0].streamSettings.httpSettings.host[0] // .inbounds[0].settings.httpSettings.host[0] // ""' "$config_file")
            ;;
        grpc)
            host=$(jq -r '.inbounds[0].streamSettings.grpc_host // .inbounds[0].settings.grpc_host // ""' "$config_file")
            ;;
        reality)
            host=$(jq -r '.inbounds[0].streamSettings.realitySettings.dest // ""' "$config_file" | cut -d: -f1)
            ;;
    esac
    
    # 使用命令行参数覆盖
    [[ -n "$PORT" ]] && inbound_port="$PORT"
    [[ -n "$UUID" ]] && uuid="$UUID"
    [[ -n "$PASSWORD" ]] && password="$PASSWORD"
    [[ -n "$DOMAIN" ]] && host="$DOMAIN"
    
    # 导出变量供其他函数使用
    export EXTRACTED_PORT="$inbound_port"
    export EXTRACTED_PROTOCOL="$protocol"
    export EXTRACTED_NETWORK="$network"
    export EXTRACTED_SECURITY="$security"
    export EXTRACTED_UUID="$uuid"
    export EXTRACTED_PASSWORD="$password"
    export EXTRACTED_HOST="$host"
    
    log_info "提取完成:"
    log_info "  端口: $inbound_port"
    log_info "  协议: $protocol"
    log_info "  传输: $network"
    log_info "  安全: $security"
    log_info "  域名: $host"
    
    return 0
}

# ========================================
# 配置变更检测
# ========================================

detect_config_changes() {
    local config_file="$1"
    
    log_info "检测 V2Ray 配置变更..."
    
    # 确保状态目录存在
    if [[ ! -d "$V2RAY_STATE_DIR" ]]; then
        mkdir -p "$V2RAY_STATE_DIR"
        log_info "创建状态目录: $V2RAY_STATE_DIR"
    fi
    
    # 计算当前配置的 SHA256 哈希值
    local current_hash
    current_hash=$(sha256sum "$config_file" | cut -d' ' -f1)
    log_debug "当前配置哈希: $current_hash"
    
    # 读取存储的哈希值
    local stored_hash=""
    if [[ -f "$STATE_FILE" ]]; then
        stored_hash=$(jq -r '.config_hash // ""' "$STATE_FILE" 2>/dev/null || echo "")
    fi
    log_debug "存储的配置哈希: $stored_hash"
    
    # 比较哈希值
    if [[ "$current_hash" == "$stored_hash" ]] && [[ -n "$stored_hash" ]] && [[ "$FORCE_DEPLOY" != "true" ]]; then
        log_info "配置未变更（SHA256: $stored_hash），跳过部署"
        return 1
    fi
    
    log_info "检测到配置变更"
    log_info "  旧哈希: ${stored_hash:-无}"
    log_info "  新哈希: $current_hash"
    
    # 更新状态文件
    local timestamp
    timestamp=$(date -Iseconds)
    jq -n --arg hash "$current_hash" --arg timestamp "$timestamp" \
        '{"config_hash": $hash, "last_updated": $timestamp}' > "$STATE_FILE"
    log_info "已更新状态文件: $STATE_FILE"
    
    return 0
}

# ========================================
# Caddy 配置生成
# ========================================

generate_caddy_config() {
    local domain="$1"
    local port="$2"
    local upstream="$3"
    local email="${4:-admin@$domain}"
    
    log_info "生成 Caddy 配置..."
    
    local caddy_dir="/etc/caddy"
    local config_dir="$caddy_dir/WangYan-Good"
    local config_file="$config_dir/v2ray-$domain.conf"
    
    # 创建目录
    mkdir -p "$config_dir"
    
    # 生成 Caddy 配置
    local config_content
    config_content=$(cat << CADDY_EOF
{$domain}:{$port} {
    reverse_proxy {$upstream}
    
    # TLS 配置
    tls {$email} {
        protocols tls1.2 tls1.3
    }
    
    # 安全头
    header {
        -Server
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # 日志
    log {
        output file /var/log/caddy/{$domain}.log
        format single_field common_log
    }
}
CADDY_EOF
)
    
    # 写入配置文件
    echo "$config_content" > "$config_file"
    log_info "Caddy 配置已写入: $config_file"
    
    # 验证 Caddy 配置
    if command -v caddy &> /dev/null; then
        log_info "验证 Caddy 配置语法..."
        if ! caddy validate --config "$config_file" &> /dev/null; then
            log_error "Caddy 配置语法验证失败"
            caddy validate --config "$config_file" 2>&1 | while read -r line; do
                log_error "  $line"
            done
            return 1
        fi
        log_info "Caddy 配置语法验证通过"
    else
        log_warn "Caddy 未安装，跳过语法验证"
    fi
    
    return 0
}

# ========================================
# Nginx 配置生成
# ========================================

generate_nginx_config() {
    local domain="$1"
    local port="$2"
    local upstream="$3"
    local ssl_cert="${4:-/etc/ssl/certs/dummy.crt}"
    local ssl_key="${5:-/etc/ssl/private/dummy.key}"
    
    log_info "生成 Nginx 配置..."
    
    local nginx_dir="/etc/nginx"
    local config_dir="$nginx_dir/v2ray"
    local config_file="$config_dir/v2ray-$domain.conf"
    
    # 创建目录
    mkdir -p "$config_dir"
    
    # 生成 Nginx 配置
    local config_content
    config_content=$(cat << NGINX_EOF
server {
    listen {$port} ssl http2;
    server_name {$domain};
    
    # SSL 配置
    ssl_certificate {$ssl_cert};
    ssl_certificate_key {$ssl_key};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    
    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    location / {
        proxy_pass {$upstream};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    access_log /var/log/nginx/{$domain}_access.log;
    error_log /var/log/nginx/{$domain}_error.log;
}
NGINX_EOF
)
    
    # 写入配置文件
    echo "$config_content" > "$config_file"
    log_info "Nginx 配置已写入: $config_file"
    
    # 创建符号链接启用站点
    local enabled_dir="$nginx_dir/sites-enabled"
    mkdir -p "$enabled_dir"
    ln -sf "$config_file" "$enabled_dir/v2ray-$domain.conf"
    log_info "已启用站点: $enabled_dir/v2ray-$domain.conf"
    
    # 验证 Nginx 配置
    if command -v nginx &> /dev/null; then
        log_info "验证 Nginx 配置语法..."
        if ! nginx -t &> /dev/null; then
            log_error "Nginx 配置语法验证失败"
            nginx -t 2>&1 | while read -r line; do
                log_error "  $line"
            done
            return 1
        fi
        log_info "Nginx 配置语法验证通过"
    else
        log_warn "Nginx 未安装，跳过语法验证"
    fi
    
    return 0
}

# ========================================
# 配置部署
# ========================================

deploy_web_proxy() {
    local protocol="$1"
    local port="$2"
    local domain="$3"
    local upstream="$4"
    local email="${5:-admin@$domain}"
    local ssl_cert="${6:-}"
    local ssl_key="${7:-}"
    
    log_info "部署 Web 代理配置..."
    log_info "  协议: $protocol"
    log_info "  端口: $port"
    log_info "  域名: $domain"
    log_info "  上游: $upstream"
    
    # 根据 Web 服务器类型部署
    case "$WEB_SERVER" in
        caddy)
            if ! generate_caddy_config "$domain" "$port" "$upstream" "$email"; then
                log_error "Caddy 配置生成失败"
                return 1
            fi
            # 重新加载 Caddy
            if command -v caddy &> /dev/null; then
                log_info "重新加载 Caddy..."
                systemctl reload caddy 2>/dev/null || caddy reload --config "/etc/caddy/Caddyfile" 2>/dev/null || {
                    log_warn "无法自动重新加载 Caddy，请手动执行: systemctl reload caddy"
                    return 1
                }
                log_info "Caddy 重新加载成功"
            fi
            ;;
        nginx)
            if ! generate_nginx_config "$domain" "$port" "$upstream" "$ssl_cert" "$ssl_key"; then
                log_error "Nginx 配置生成失败"
                return 1
            fi
            # 重新加载 Nginx
            if command -v nginx &> /dev/null; then
                log_info "重新加载 Nginx..."
                systemctl reload nginx 2>/dev/null || nginx -s reload 2>/dev/null || {
                    log_warn "无法自动重新加载 Nginx，请手动执行: systemctl reload nginx"
                    return 1
                }
                log_info "Nginx 重新加载成功"
            fi
            ;;
        *)
            log_error "未指定 Web 服务器类型"
            return 1
            ;;
    esac
    
    log_info "Web 代理部署成功"
    return 0
}

# ========================================
# 配置清理
# ========================================

cleanup_web_proxy() {
    local domain="$1"
    
    log_info "清理 Web 代理配置..."
    
    case "$WEB_SERVER" in
        caddy)
            local config_file="/etc/caddy/WangYan-Good/v2ray-$domain.conf"
            if [[ -f "$config_file" ]]; then
                log_info "删除 Caddy 配置: $config_file"
                rm -f "$config_file"
                
                # 检查是否还有其他配置
                local config_dir="/etc/caddy/WangYan-Good"
                if [[ -d "$config_dir" ]] && [[ -z "$(ls -A "$config_dir" 2>/dev/null)" ]]; then
                    log_info "配置目录为空，保留目录结构"
                fi
            else
                log_info "Caddy 配置不存在: $config_file"
            fi
            ;;
        nginx)
            local config_file="/etc/nginx/v2ray/v2ray-$domain.conf"
            local enabled_file="/etc/nginx/sites-enabled/v2ray-$domain.conf"
            
            if [[ -L "$enabled_file" ]]; then
                log_info "删除符号链接: $enabled_file"
                rm -f "$enabled_file"
            elif [[ -f "$config_file" ]]; then
                log_info "删除 Nginx 配置: $config_file"
                rm -f "$config_file"
            else
                log_info "Nginx 配置不存在"
                return 0
            fi
            
            # 重新加载 Nginx
            if command -v nginx &> /dev/null; then
                log_info "重新加载 Nginx..."
                systemctl reload nginx 2>/dev/null || nginx -s reload 2>/dev/null || {
                    log_warn "无法自动重新加载 Nginx，请手动执行: systemctl reload nginx"
                    return 1
                }
                log_info "Nginx 重新加载成功"
            fi
            ;;
        *)
            log_error "未指定 Web 服务器类型"
            return 1
            ;;
    esac
    
    log_info "Web 代理清理完成"
    return 0
}

# ========================================
# 错误处理
# ========================================

handle_deployment_failure() {
    local error_msg="$1"
    local suggestion="$2"
    
    log_error "部署失败: $error_msg"
    log_error "建议解决方案: $suggestion"
    
    # 在非交互式模式下直接返回错误
    if [[ "$V2RAY_NON_INTERACTIVE" == "1" ]] || [[ "$SILENT_MODE" == "true" ]]; then
        return 1
    fi
    
    # 交互式模式：询问用户
    read -p "请选择操作 [r]重试 / [s]跳过此配置 / [a]中止部署: " choice
    
    case "$choice" in
        [Rr]*)
            log_info "重试..."
            return 0
            ;;
        [Ss]*)
            log_info "跳过当前配置"
            return 1
            ;;
        [Aa]*)
            log_error "中止部署"
            exit 1
            ;;
        *)
            log_error "未知选择"
            return 1
            ;;
    esac
}

# ========================================
# 主部署函数
# ========================================

auto_deploy_vps_architecture() {
    local config_file="$1"
    local web_server="$2"
    local force_deploy="${3:-false}"
    
    log_info "=========================================="
    log_info "V2Ray VPS 架构自动部署"
    log_info "=========================================="
    
    # 保存原始参数
    local original_web_server="$WEB_SERVER"
    local original_force_deploy="$FORCE_DEPLOY"
    
    # 设置参数
    WEB_SERVER="$web_server"
    FORCE_DEPLOY="$force_deploy"
    
    # 检查依赖
    if ! check_dependencies; then
        log_error "依赖检查失败"
        return 1
    fi
    
    # 验证配置文件
    if ! validate_v2ray_config "$config_file"; then
        if handle_deployment_failure "V2Ray 配置无效" "请检查 V2Ray 配置文件语法和结构"; then
            return 0
        else
            return 1
        fi
    fi
    
    # 检测配置变更
    if ! detect_config_changes "$config_file"; then
        if [[ "$force_deploy" != "true" ]]; then
            log_info "配置未变更，跳过部署"
            return 0
        fi
    fi
    
    # 提取配置信息
    if ! extract_v2ray_config "$config_file"; then
        log_error "配置信息提取失败"
        return 1
    fi
    
    # 检查是否需要 TLS 代理
    if [[ "$EXTRACTED_SECURITY" == "tls" ]] || [[ -z "$EXTRACTED_SECURITY" ]]; then
        case "$EXTRACTED_NETWORK" in
            ws|h2|grpc)
                log_info "检测到需要 TLS 终止代理的协议: $EXTRACTED_NETWORK"
                ;;
            *)
                log_info "协议不需要 TLS 终止代理: $EXTRACTED_NETWORK"
                return 0
                ;;
        esac
    else
        log_info "配置使用: $EXTRACTED_SECURITY"
    fi
    
    # 验证必需参数
    if [[ -z "$EXTRACTED_HOST" ]]; then
        log_error "缺少必需参数: 域名 (host)"
        if handle_deployment_failure "缺少域名参数" "请确保 V2Ray 配置包含有效的域名"; then
            return 0
        else
            return 1
        fi
    fi
    
    if [[ -z "$EXTRACTED_PORT" ]]; then
        log_error "缺少必需参数: 端口 (port)"
        if handle_deployment_failure "缺少端口参数" "请确保 V2Ray 配置包含有效的端口"; then
            return 0
        else
            return 1
        fi
    fi
    
    # 构建上游地址
    local upstream="127.0.0.1:$EXTRACTED_PORT"
    
    # 获取 SSL 证书信息（如果需要）
    local ssl_cert=""
    local ssl_key=""
    if [[ "$WEB_SERVER" == "nginx" ]]; then
        ssl_cert="${SSL_CERT_PATH:-/etc/ssl/certs/dummy.crt}"
        ssl_key="${SSL_KEY_PATH:-/etc/ssl/private/dummy.key}"
    fi
    
    # 部署 Web 代理
    if ! deploy_web_proxy \
        "$EXTRACTED_PROTOCOL" \
        "$EXTRACTED_PORT" \
        "$EXTRACTED_HOST" \
        "$upstream" \
        "admin@$EXTRACTED_HOST" \
        "$ssl_cert" \
        "$ssl_key"; then
        if handle_deployment_failure "Web 代理部署失败" "请检查 Web 服务器配置和权限"; then
            return 0
        else
            return 1
        fi
    fi
    
    log_info "=========================================="
    log_info "部署成功!"
    log_info "=========================================="
    log_info "协议: $EXTRACTED_PROTOCOL"
    log_info "域名: $EXTRACTED_HOST"
    log_info "端口: $EXTRACTED_PORT"
    log_info "Web 服务器: $WEB_SERVER"
    
    # 恢复原始参数
    WEB_SERVER="$original_web_server"
    FORCE_DEPLOY="$original_force_deploy"
    
    return 0
}

# ========================================
# 主清理函数
# ========================================

cleanup_vps_architecture() {
    local config_file="$1"
    local web_server="$2"
    
    log_info "=========================================="
    log_info "V2Ray VPS 架构清理"
    log_info "=========================================="
    
    # 保存原始参数
    local original_web_server="$WEB_SERVER"
    
    # 设置参数
    WEB_SERVER="$web_server"
    
    # 检查依赖
    if ! check_dependencies; then
        log_warn "依赖检查失败，但仍继续清理"
    fi
    
    # 提取配置信息
    if ! extract_v2ray_config "$config_file"; then
        log_warn "配置信息提取失败，尝试使用文件名作为域名"
        local basename
        basename=$(basename "$config_file" .json)
        export EXTRACTED_HOST="${basename#v2ray-}"
        export EXTRACTED_HOST="${EXTRACTED_HOST#Trojan-}"
        export EXTRACTED_HOST="${EXTRACTED_HOST#VMess-}"
        export EXTRACTED_HOST="${EXTRACTED_HOST#VLESS-}"
        export EXTRACTED_HOST="${EXTRACTED_HOST#Shadowsocks-}"
    fi
    
    # 清理 Web 代理
    if [[ -n "$EXTRACTED_HOST" ]]; then
        if ! cleanup_web_proxy "$EXTRACTED_HOST"; then
            log_warn "Web 代理清理失败"
        fi
    else
        log_error "无法确定要清理的域名"
        return 1
    fi
    
    log_info "=========================================="
    log_info "清理完成!"
    log_info "=========================================="
    
    # 恢复原始参数
    WEB_SERVER="$original_web_server"
    
    return 0
}

# ========================================
# 状态显示
# ========================================

show_status() {
    log_info "=========================================="
    log_info "V2Ray VPS 架构状态"
    log_info "=========================================="
    
    # 显示状态文件
    if [[ -f "$STATE_FILE" ]]; then
        log_info "状态文件: $STATE_FILE"
        log_info "内容:"
        jq . "$STATE_FILE" 2>/dev/null || cat "$STATE_FILE"
    else
        log_info "状态文件不存在: $STATE_FILE"
    fi
    
    # 显示 Caddy 配置
    if command -v caddy &> /dev/null; then
        local caddy_conf="/etc/caddy/WangYan-Good"
        if [[ -d "$caddy_conf" ]]; then
            log_info "Caddy 配置目录: $caddy_conf"
            log_info "配置文件:"
            ls -lh "$caddy_conf"/*.conf 2>/dev/null || log_info "  无配置文件"
        fi
    fi
    
    # 显示 Nginx 配置
    if command -v nginx &> /dev/null; then
        local nginx_conf="/etc/nginx/v2ray"
        if [[ -d "$nginx_conf" ]]; then
            log_info "Nginx 配置目录: $nginx_conf"
            log_info "配置文件:"
            ls -lh "$nginx_conf"/*.conf 2>/dev/null || log_info "  无配置文件"
        fi
    fi
    
    # 显示服务状态
    if command -v systemctl &> /dev/null; then
        log_info "服务状态:"
        if command -v caddy &> /dev/null; then
            log_info "  Caddy:"
            systemctl status caddy --no-pager 2>/dev/null | head -5 || echo "  无法获取状态"
        fi
        if command -v nginx &> /dev/null; then
            log_info "  Nginx:"
            systemctl status nginx --no-pager 2>/dev/null | head -5 || echo "  无法获取状态"
        fi
    fi
}

# ========================================
# 验证配置
# ========================================

validate_config() {
    local config_file="$1"
    
    log_info "=========================================="
    log_info "配置验证"
    log_info "=========================================="
    
    # V2Ray 配置验证
    if validate_v2ray_config "$config_file"; then
        log_info "V2Ray 配置验证通过"
    else
        log_error "V2Ray 配置验证失败"
        return 1
    fi
    
    # 检查必需参数
    local port protocol host
    port=$(jq -r '.inbounds[0].port // ""' "$config_file")
    protocol=$(jq -r '.inbounds[0].protocol // ""' "$config_file")
    
    # 检查是否需要 TLS
    local network security
    network=$(jq -r '.inbounds[0].streamSettings.network // .inbounds[0].settings.network // ""' "$config_file")
    security=$(jq -r '.inbounds[0].streamSettings.security // .inbounds[0].settings.security // ""' "$config_file")
    
    log_info "V2Ray 配置信息:"
    log_info "  端口: $port"
    log_info "  协议: $protocol"
    log_info "  传输: $network"
    log_info "  安全: $security"
    
    # 需要 TLS 的协议
    case "$network" in
        ws|h2|grpc)
            case "$security" in
                tls|"")
                    log_info "此配置需要 TLS 终止代理"
                    ;;
                *)
                    log_info "配置使用 $security，无需 TLS 终止代理"
                    ;;
            esac
            ;;
        *)
            log_info "此配置不需要 TLS 终止代理"
            ;;
    esac
    
    return 0
}

# ========================================
# 主函数
# ========================================

main() {
    # 解析参数
    parse_args "$@"
    
    # 设置静默模式
    if [[ "$SILENT_MODE" == "true" ]]; then
        LOG_LEVEL="error"
        exec 2>/dev/null
    fi
    
    # 执行命令
    case "$COMMAND" in
        deploy)
            if [[ -z "$V2RAY_CONFIG" ]]; then
                log_error "缺少必需参数: --config"
                exit 1
            fi
            
            if [[ -z "$WEB_SERVER" ]]; then
                # 自动检测 Web 服务器
                if command -v caddy &> /dev/null; then
                    WEB_SERVER="caddy"
                elif command -v nginx &> /dev/null; then
                    WEB_SERVER="nginx"
                else
                    log_error "未检测到 Web 服务器 (Caddy 或 Nginx)"
                    exit 1
                fi
            fi
            
            auto_deploy_vps_architecture "$V2RAY_CONFIG" "$WEB_SERVER" "$FORCE_DEPLOY"
            ;;
        cleanup)
            if [[ -z "$V2RAY_CONFIG" ]]; then
                log_error "缺少必需参数: --config"
                exit 1
            fi
            
            if [[ -z "$WEB_SERVER" ]]; then
                # 自动检测 Web 服务器
                if command -v caddy &> /dev/null; then
                    WEB_SERVER="caddy"
                elif command -v nginx &> /dev/null; then
                    WEB_SERVER="nginx"
                else
                    log_error "未检测到 Web 服务器 (Caddy 或 Nginx)"
                    exit 1
                fi
            fi
            
            cleanup_vps_architecture "$V2RAY_CONFIG" "$WEB_SERVER"
            ;;
        validate)
            if [[ -z "$V2RAY_CONFIG" ]]; then
                log_error "缺少必需参数: --config"
                exit 1
            fi
            
            validate_config "$V2RAY_CONFIG"
            ;;
        status)
            show_status
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
    
    # 清理临时状态
    unset V2RAY_CONFIG
    unset WEB_SERVER
    unset DOMAIN
    unset PORT
    unset FORCE_DEPLOY
    unset SILENT_MODE
    unset LOG_LEVEL
    
    log_info "执行完成"
}

# 运行主函数（如果脚本是直接执行的）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi