#!/bin/bash
# Caddy 配置验证优化模块
# 实现环境一致性原则下的智能诊断与自动修正

# =============================================================================
# 配置常量
# =============================================================================
readonly CADDY_CONFIG_DIR="/etc/caddy"
readonly CADDY_CONFIG_FILE="Caddyfile"
readonly PLACEHOLDER_DOMAINS=("yourdomain.com" "example.com" "example.org" "placeholder.com")

# 诊断代码常量
readonly DIAG_CODE_OTHER=0
readonly DIAG_CODE_DNS=1
readonly DIAG_CODE_CLOUDFLARE=2
readonly DIAG_CODE_PLACEHOLDER=3
readonly DIAG_CODE_VERSION=4

# 诊断别名（用于兼容性）
readonly DIAG_CODE_DNS_ISSUE=1
readonly DIAG_CODE_VERSION_COMPAT=4

# 日志文件 - 可被环境变量覆盖
# 使用: ${VAR:=default} 语法，但需要在 readonly 之前设置
if [[ -z "${LOG_FILE:-}" ]]; then
    LOG_FILE="${V2RAY_LOG_FILE:-/var/log/v2ray-deploy.log}"
fi
# readonly LOG_FILE  # 已移除：测试脚本需要覆盖该变量

# =============================================================================
# 日志记录模块
# =============================================================================
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # 确保日志目录存在（MVP 简化版）
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        if ! mkdir -p "$log_dir" 2>/dev/null; then
            # 降级策略：尝试 /tmp
            local fallback_dir="/tmp/v2ray-logs-$$"
            if mkdir -p "$fallback_dir" 2>/dev/null; then
                log_dir="$fallback_dir"
                LOG_FILE="$fallback_dir/v2ray-deploy.log"
            else
                # 最终降级：静默失败
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [v2ray-deploy] 无法创建日志目录" >&2
                return 0
            fi
        fi
    fi

    # 写入日志
    {
        echo "[$timestamp] [$level] [v2ray-deploy] $message"
    } >> "$LOG_FILE" 2>/dev/null || true

    # 错误输出到 stderr
    if [[ "$level" == "ERROR" || "$level" == "WARN" ]]; then
        echo "[$level] $message" >&2
    fi
}

# 环境标识（可由主脚本传入）
IDENTIFY_ENVIRONMENT() {
    local env="production"
    if [[ "${V2RAY_ENV:-}" == "development" ]]; then
        env="development"
    elif [[ "${V2RAY_ENV:-}" == "testing" ]]; then
        env="testing"
    fi
    echo "$env"
}

# =============================================================================
# 初始化函数
# =============================================================================
init_validation_module() {
    # 确保日志目录存在
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || true
    fi
    
    log_message "INFO" "Caddy 验证优化模块初始化完成"
    log_message "INFO" "运行环境: $(IDENTIFY_ENVIRONMENT)"
}

# =============================================================================
# 智能诊断分析函数
# =============================================================================
analyze_validation_error() {
    local error_log="$1"
    local diagnostic_code=0
    
    # 空错误日志检查
    if [[ -z "$error_log" ]]; then
        log_message "WARN" "analyze_validation_error: 空错误日志"
        echo "$diagnostic_code"
        return
    fi
    
    # 诊断日志
    log_message "INFO" "开始分析 Caddy 配置验证错误"
    
    # 检查占位符域名 (优先检查，避免与 DNS 误判)
    for placeholder in "${PLACEHOLDER_DOMAINS[@]}"; do
        if echo "$error_log" | grep -qi "$placeholder"; then
            log_message "INFO" "诊断结果: 发现占位符域名 (诊断码: 3) - $placeholder"
            diagnostic_code=$DIAG_CODE_PLACEHOLDER
            echo "$diagnostic_code"
            return
        fi
    done
    
    # 检查 DNS 相关错误 (其次检查)
    if echo "$error_log" | grep -qiE "(dns|resolver|resolve|NXDOMAIN|SERVFAIL)"; then
        log_message "INFO" "诊断结果: DNS 配置问题 (诊断码: 1)"
        diagnostic_code=$DIAG_CODE_DNS
        echo "$diagnostic_code"
        return
    fi
    
    # 检查 Caddy 版本兼容性问题 (优先于 DNS 检查)
    if echo "$error_log" | grep -qiE "(version|VERSION|incompatible|compatibility|json: unknown field)"; then
        log_message "INFO" "诊断结果: Caddy 版本兼容性问题 (诊断码: 4)"
        diagnostic_code=$DIAG_CODE_VERSION
        echo "$diagnostic_code"
        return
    fi
    
    # 检查 Cloudflare API 问题
    if echo "$error_log" | grep -qiE "(cloudflare|API|token|credential)"; then
        log_message "INFO" "诊断结果: Cloudflare API 问题 (诊断码: 2)"
        diagnostic_code=$DIAG_CODE_CLOUDFLARE
        echo "$diagnostic_code"
        return
    fi
    
    # 其他问题
    log_message "INFO" "诊断结果: 其他配置问题 (诊断码: 0)"
    diagnostic_code=$DIAG_CODE_OTHER
    echo "$diagnostic_code"
}

# =============================================================================
# 自动修正函数
# =============================================================================
attempt_auto_fix() {
    local config_path="$1"
    local diagnostic_code="$2"
    local fix_success=false
    
    if [[ -z "$config_path" ]]; then
        log_message "ERROR" "attempt_auto_fix: 配置路径为空"
        echo "$fix_success"
        return 1
    fi
    
    log_message "INFO" "尝试自动修正配置文件: $config_path (诊断码: $diagnostic_code)"
    
    # 仅处理占位符域名（code=3） - 安全场景
    if [[ "$diagnostic_code" -eq "$DIAG_CODE_PLACEHOLDER" ]]; then
        # 检查配置文件存在
        if [[ ! -f "$config_path" ]]; then
            log_message "ERROR" "配置文件不存在: $config_path"
            echo "$fix_success"
            return 1
        fi
        
        # 获取主机名
        local hostname
        hostname=$(hostname 2>/dev/null || echo "unknown")
        local local_domain="${hostname}.local"
        
        log_message "INFO" "检测到占位符域名，开始自动替换"
        log_message "INFO" "替换目标: $local_domain"
        
        # 备份原配置
        local backup_path="${config_path}.backup.$(date '+%Y%m%d%H%M%S')"
        cp "$config_path" "$backup_path"
        log_message "INFO" "已备份原配置到: $backup_path"
        
        # 执行替换
        local temp_file
        temp_file=$(mktemp)
        
        # 替换所有占位符域名
        sed -E \
            -e 's/yourdomain\.com/'"$local_domain"'/gi' \
            -e 's/example\.com/'"$local_domain"'/gi' \
            -e 's/example\.org/'"$local_domain"'/gi' \
            -e 's/placeholder\.com/'"$local_domain"'/gi' \
            "$config_path" > "$temp_file"
        
        # 验证替换后的配置
        if caddy validate --config "$temp_file" 2>&1 | grep -qi "error"; then
            log_message "WARN" "替换后配置验证仍失败，回滚更改"
            rm -f "$temp_file"
            echo "$fix_success"
            return 1
        fi
        
        # 应用新配置
        mv "$temp_file" "$config_path"
        fix_success=true
        
        log_message "INFO" "自动修正成功: 占位符已替换为 $local_domain"
    else
        log_message "WARN" "不支持自动修正的诊断码: $diagnostic_code"
    fi
    
    echo "$fix_success"
}

# =============================================================================
# 统一验证处理函数
# =============================================================================
handle_validation_failure() {
    local config_path="$1"
    local skip_checks="$2"  # --skip-dns-check, --skip-tls-check
    local force_deploy=false
    local skip_dns=false
    local skip_tls=false
    local no_auto_fix=false
    
    # 解析 skip_checks 参数
    if [[ -n "$skip_checks" ]]; then
        if echo "$skip_checks" | grep -q "\-\-force\-deploy"; then
            force_deploy=true
        fi
        if echo "$skip_checks" | grep -q "\-\-skip\-dns\-check"; then
            skip_dns=true
        fi
        if echo "$skip_checks" | grep -q "\-\-skip\-tls\-check"; then
            skip_tls=true
        fi
        if echo "$skip_checks" | grep -q "\-\-no\-auto\-fix"; then
            no_auto_fix=true
        fi
    fi
    
    # 当前环境
    local current_env
    current_env=$(IDENTIFY_ENVIRONMENT)
    
    log_message "INFO" "开始处理验证失败 (环境: $current_env)"
    log_message "INFO" "force_deploy: $force_deploy, skip_dns: $skip_dns, skip_tls: $skip_tls, no_auto_fix: $no_auto_fix"
    
    # 尝试获取错误日志
    local error_log=""
    if [[ -n "${CADDY_ERROR_LOG:-}" ]]; then
        error_log="$CADDY_ERROR_LOG"
    elif [[ -f "${config_path}.error.log" ]]; then
        error_log=$(cat "${config_path}.error.log" 2>/dev/null)
    fi
    
    # 进行智能诊断
    local diagnostic_code
    diagnostic_code=$(analyze_validation_error "$error_log")
    
    log_message "INFO" "诊断完成，代码: $diagnostic_code"
    
    # 根据诊断码处理
    case "$diagnostic_code" in
        $DIAG_CODE_PLACEHOLDER)
            # 占位符域名：可自动修正
            log_message "WARN" "检测到占位符域名 (yourdomain.com/example.com 等)"
            
            if [[ "$force_deploy" == "true" ]]; then
                log_message "WARN" "强制部署模式：跳过所有检查"
                return 0
            elif [[ "$no_auto_fix" == "true" ]]; then
                log_message "ERROR" "自动修正已禁用。请使用 --no-auto-fix=false 或提供有效配置"
                return 1
            else
                # 自动修正
                if attempt_auto_fix "$config_path" "$diagnostic_code"; then
                    log_message "INFO" "自动修正成功，重新验证中..."
                    # 重新验证
                    if caddy validate --config "$config_path" 2>&1; then
                        log_message "INFO" "验证通过"
                        return 0
                    else
                        log_message "ERROR" "自动修正后验证仍失败"
                        return 1
                    fi
                else
                    log_message "ERROR" "自动修正失败"
                    return 1
                fi
            fi
            ;;
            
        $DIAG_CODE_DNS)
            # DNS 配置问题：严格中止（除非 skip）
            log_message "ERROR" "检测到 DNS 配置问题"
            log_message "INFO" "DNS 问题说明：目标域名可能未正确解析到本机 IP"
            
            if [[ "$skip_dns" == "true" || "$force_deploy" == "true" ]]; then
                log_message "WARN" "已通过 --skip-dns-check 或 --force-deploy 跳过 DNS 检查"
                return 0
            else
                log_message "ERROR" "DNS 配置问题中止部署。请先检查 DNS 配置或使用 --skip-dns-check"
                return 1
            fi
            ;;
            
        $DIAG_CODE_CLOUDFLARE)
            # Cloudflare API 问题：严格中止
            log_message "ERROR" "检测到 Cloudflare API 问题"
            log_message "INFO" "Cloudflare 问题说明：API 令牌无效或权限不足"
            
            if [[ "$force_deploy" == "true" ]]; then
                log_message "WARN" "强制部署模式：跳过所有检查"
                return 0
            else
                log_message "ERROR" "Cloudflare API 问题中止部署。请检查 API 令牌或使用 --force-deploy"
                return 1
            fi
            ;;
            
        $DIAG_CODE_VERSION)
            # Caddy 版本兼容性：严格中止
            log_message "ERROR" "检测到 Caddy 版本兼容性问题"
            log_message "INFO" "版本问题说明：Caddyfile 语法与当前 Caddy 版本不兼容"
            
            if [[ "$force_deploy" == "true" ]]; then
                log_message "WARN" "强制部署模式：跳过所有检查"
                return 0
            else
                log_message "ERROR" "版本兼容性问题中止部署。请更新 Caddy 或修正配置"
                return 1
            fi
            ;;
            
        $DIAG_CODE_OTHER)
            # 其他复杂问题：严格中止
            log_message "ERROR" "检测到其他配置问题"
            log_message "INFO" "详细错误请查看: $LOG_FILE"
            
            if [[ "$force_deploy" == "true" ]]; then
                log_message "WARN" "强制部署模式：跳过所有检查"
                return 0
            else
                log_message "ERROR" "配置问题中止部署。请查看日志获取详细信息"
                return 1
            fi
            ;;
            
        *)
            log_message "ERROR" "未知诊断结果"
            return 1
            ;;
    esac
}

# =============================================================================
# 命令行参数解析
# =============================================================================
parse_cli_args() {
    local skip_checks=""
    
    for arg in "$@"; do
        case "$arg" in
            --skip-dns-check)
                skip_checks="$skip_checks --skip-dns-check"
                ;;
            --skip-tls-check)
                skip_checks="$skip_checks --skip-tls-check"
                ;;
            --force-deploy)
                skip_checks="$skip_checks --force-deploy"
                ;;
            --dev-mode)
                # 开发模式：自动配置本地 DNS/TLS
                log_message "INFO" "开发模式启用：自动配置本地环境"
                configure_dev_mode
                skip_checks="$skip_checks --skip-dns-check --skip-tls-check"
                ;;
            --no-auto-fix)
                skip_checks="$skip_checks --no-auto-fix"
                ;;
            *)
                # 其他参数保持传递
                ;;
        esac
    done
    
    echo "$skip_checks"
}

# 开发模式配置
configure_dev_mode() {
    log_message "INFO" "配置开发模式环境"
    
    # 自动设置本地域名
    local hostname
    hostname=$(hostname 2>/dev/null || echo "v2ray-server")
    export V2RAY_LOCAL_DOMAIN="${hostname}.local"
    
    # 自动配置 Caddy
    if [[ -f "$CADDY_CONFIG_DIR/$CADDY_CONFIG_FILE" ]]; then
        # 备份并更新本地域名
        cp "$CADDY_CONFIG_DIR/$CADDY_CONFIG_FILE" "${CADDY_CONFIG_DIR}/${CADDY_CONFIG_FILE}.dev.backup"
        
        # 替换为本地域名
        sed -i "s/yourdomain\.com/$V2RAY_LOCAL_DOMAIN/g" "$CADDY_CONFIG_DIR/$CADDY_CONFIG_FILE"
        sed -i "s/example\.com/$V2RAY_LOCAL_DOMAIN/g" "$CADDY_CONFIG_DIR/$CADDY_CONFIG_FILE"
        
        log_message "INFO" "已将 Caddy 配置中的域名替换为 $V2RAY_LOCAL_DOMAIN"
    fi
}

# =============================================================================
# 主流程入口
# =============================================================================
main() {
    # 初始化模块
    init_validation_module
    
    # 解析参数
    local skip_checks
    skip_checks=$(parse_cli_args "$@")
    
    # 配置文件路径（默认路径，可被覆盖）
    local config_path="${1:-$CADDY_CONFIG_DIR/$CADDY_CONFIG_FILE}"
    shift 2>/dev/null || true
    
    log_message "INFO" "运行参数: skip_checks='$skip_checks', config_path='$config_path'"
    
    # 在此处集成到主流程
    # 示例：当 Caddy 验证失败时调用 handle_validation_failure
    
    # 返回 skip_checks 参数供主流程使用
    echo "$skip_checks"
}

# =============================================================================
# 实用性函数
# =============================================================================

# 验证 Caddy 配置并处理错误
validate_caddy_config() {
    local config_path="$1"
    local error_output=""
    
    # 执行验证
    if ! error_output=$(caddy validate --config "$config_path" 2>&1); then
        log_message "ERROR" "Caddy 配置验证失败"
        
        # 保存错误日志
        if [[ -n "$config_path" ]]; then
            echo "$error_output" > "${config_path}.error.log"
            export CADDY_ERROR_LOG="$error_output"
        fi
        
        return 1
    fi
    
    return 0
}

# 依赖检查
check_dependencies() {
    local missing_deps=()
    
    for cmd in caddy sed; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_message "ERROR" "缺少依赖: ${missing_deps[*]}"
        return 1
    fi
    
    log_message "INFO" "所有依赖已满足"
    return 0
}

# =============================================================================
# 使用示例
# =============================================================================
usage() {
    cat << EOF
Caddy 配置验证优化模块使用说明

用法:
    source caddy-validation-optimizer.sh
    skip_checks=\$(parse_cli_args "\$@")
    handle_validation_failure "/etc/caddy/Caddyfile" "\$skip_checks"

参数:
    --skip-dns-check      跳过 DNS 检查（仅开发环境）
    --skip-tls-check      跳过 TLS 检查（仅开发环境）
    --force-deploy        强制部署（跳过所有检查）
    --dev-mode            开发模式（自动配置本地 DNS/TLS）
    --no-auto-fix         禁用自动修正

诊断代码:
    0 = 其他问题
    1 = DNS 配置问题
    2 = Cloudflare API 问题
    3 = 占位符域名 (可自动修正)
    4 = Caddy 版本兼容性

示例场景:

1. 主流程集成:
    if ! caddy validate --config /etc/caddy/Caddyfile 2>&1; then
        skip_checks=\$(parse_cli_args "\$@")
        handle_validation_failure "/etc/caddy/Caddyfile" "\$skip_checks"
        exit \$?
    fi

2. 命令行调用:
    ./caddy-validation-optimizer.sh --dev-mode

3. 手动诊断:
    analyze_validation_error "error log content"
    echo \$?

环境变量:
    V2RAY_ENV             环境标识 (production|testing|development)
    LOG_FILE              自定义日志文件路径

日志位置: /var/log/v2ray-deploy.log

EOF
}

# 如果直接执行此脚本（非 source），显示用法
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
    case "${1:-}" in
        --help|-h)
            usage
            ;;
        *)
            main "$@"
            ;;
    esac
fi
