# 集成示例：v2ray-vps-auto-deploy.sh

本文件展示如何将 Caddy 验证优化模块集成到现有的 V2Ray 部署脚本中。

## 示例一：最小集成（推荐用于快速修复）

```bash
#!/bin/bash
set -euo pipefail

# ==================== Caddy 验证优化模块集成 ====================
# 在脚本顶部添加以下代码
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CADDY_VALIDATOR="$SCRIPT_DIR/caddy-validation-optimizer.sh"

if [[ -f "$CADDY_VALIDATOR" ]]; then
    source "$CADDY_VALIDATOR"
fi

# ==================== 原始脚本代码 ====================

# 1. 部署准备函数
prepare_deployment() {
    echo "[INFO] 开始部署准备..."
    
    # 检查 Caddy 是否安装
    if ! command -v caddy >/dev/null 2>&1; then
        echo "[ERROR] Caddy 未安装"
        exit 1
    fi
    
    # 获取主机名
    HOSTNAME=$(hostname 2>/dev/null || echo "v2ray-server")
    export V2RAY_HOSTNAME="$HOSTNAME"
    
    # 生成配置文件
    generate_caddy_config
    
    log_message "INFO" "配置文件生成完成"
}

# 2. 生成 Caddy 配置（示例）
generate_caddy_config() {
    local config_file="/etc/caddy/Caddyfile"
    
    cat > "$config_file" << EOF
{
    admin off
}

:443 {
    reverse_proxy localhost:8080
    tls {
        dns cloudflare ${CLOUDFLARE_API_TOKEN:-placeholder_token}
    }
}

# 占位符域名（会被自动替换）
:443 {
    reverse_proxy localhost:8080
}
EOF
    
    log_message "INFO" "Caddy 配置已保存到 $config_file"
}

# 3. 部署主函数（关键修改处）
deploy() {
    echo "[INFO] 开始部署 V2Ray..."
    
    # ==================== 原始验证代码（有问题的代码） ====================
    # if ! caddy validate --config /etc/caddy/Caddyfile 2>&1; then
    #     echo "[ERROR] Caddy 配置验证失败"
    #     read -p "是否继续？[y/N] " -n 1 -r
    #     if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    #         exit 1
    #     fi
    # }

    # ==================== 新验证代码（替换上面的部分） ====================
    
    # 解析命令行参数
    SKIP_CHECKS=""
    if [[ $# -gt 0 ]]; then
        SKIP_CHECKS=$(parse_cli_args "$@")
    fi
    
    # 执行验证
    if ! caddy validate --config /etc/caddy/Caddyfile 2>&1; then
        echo "[ERROR] Caddy 配置验证失败"
        
        # 调用优化后的处理函数
        if ! handle_validation_failure "/etc/caddy/Caddyfile" "$SKIP_CHECKS"; then
            echo "[FATAL] 部署中止，请检查配置或使用 --force-deploy 强制部署"
            exit 1
        fi
    fi
    
    echo "[INFO] Caddy 配置验证通过"
    
    # 重新加载 Caddy 配置
    if ! caddy reload --config /etc/caddy/Caddyfile; then
        echo "[ERROR] Caddy 配置重载失败"
        exit 1
    fi
    
    echo "[INFO] Caddy 配置已更新"
    
    # 继续部署其他组件...
    echo "[INFO] V2Ray 部署成功"
}

# ==================== 主流程 ====================

main() {
    # 初始化模块（可选，已在 handle_validation_failure 中调用）
    # init_validation_module
    
    case "${1:-deploy}" in
        deploy)
            prepare_deployment
            deploy "${@:2}"
            ;;
        help|--help|-h)
            echo "用法: $0 [deploy] [--skip-dns-check] [--skip-tls-check] [--force-deploy] [--dev-mode]"
            echo ""
            echo "选项:"
            echo "  --skip-dns-check    跳过 DNS 检查（开发环境）"
            echo "  --skip-tls-check    跳过 TLS 检查（开发环境）"
            echo "  --force-deploy      强制部署（跳过所有检查）"
            echo "  --dev-mode          开发模式（自动配置本地 DNS/TLS）"
            ;;
        *)
            echo "未知命令: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
```

## 示例二：完整集成（带开发模式支持）

```bash
#!/bin/bash
set -euo pipefail

# ==================== Caddy 验证优化模块集成 ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CADDY_VALIDATOR="$SCRIPT_DIR/caddy-validation-optimizer.sh"

if [[ -f "$CADDY_VALIDATOR" ]]; then
    source "$CADDY_VALIDATOR"
fi

# ==================== 配置变量 ====================
V2RAY_CONFIG_DIR="/etc/v2ray"
CADDY_CONFIG_DIR="/etc/caddy"
CADDY_CONFIG_FILE="$CADDY_CONFIG_DIR/Caddyfile"

# ==================== 工具函数 ====================

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

check_dependencies() {
    local missing=()
    
    for cmd in caddy v2ray jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_message "ERROR" "缺少依赖: ${missing[*]}"
        return 1
    fi
    
    log_message "INFO" "所有依赖已满足"
}

# ==================== 部署函数 ====================

setup_environment() {
    log_message "INFO" "设置部署环境..."
    
    # 设置环境标识
    export V2RAY_ENV="${V2RAY_ENV:-production}"
    
    # 确保配置目录存在
    mkdir -p "$V2RAY_CONFIG_DIR" "$CADDY_CONFIG_DIR"
    
    log_message "INFO" "运行环境: $V2RAY_ENV"
}

generate_v2ray_config() {
    local config_file="$V2RAY_CONFIG_DIR/config.json"
    
    cat > "$config_file" << EOF
{
    "inbounds": [
        {
            "port": 8080,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$(uuidgen)",
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/v2ray"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
    
    log_message "INFO" "V2Ray 配置生成完成"
}

generate_caddy_config() {
    local config_file="$CADDY_CONFIG_FILE"
    local hostname
    hostname=$(hostname 2>/dev/null || echo "v2ray-server")
    
    cat > "$config_file" << EOF
{
    "admin": {
        "disabled": true
    }
}

:443 {
    reverse_proxy localhost:8080 {
        rewrite /v2ray /v2ray
    }
    tls {
       dns cloudflare ${CLOUDFLARE_API_TOKEN:-placeholder_token}
    }
}

:80 {
    redir https://{host}{uri}
}
EOF
    
    # 如果是开发模式，使用占位符（会被自动替换）
    if [[ "${V2RAY_ENV:-}" == "development" ]]; then
        cat >> "$config_file" << EOF

:443 {
    reverse_proxy localhost:8080
    tls {
        dns cloudflare ${CLOUDFLARE_API_TOKEN:-placeholder_token}
    }
}
EOF
    fi
    
    log_message "INFO" "Caddy 配置生成完成"
}

validate_deployment() {
    log_message "INFO" "验证部署配置..."
    
    # 解析命令行参数
    local skip_checks=""
    if [[ $# -gt 0 ]]; then
        skip_checks=$(parse_cli_args "$@")
    fi
    
    # 检查 Caddy 配置
    log_message "INFO" "验证 Caddy 配置..."
    if ! caddy validate --config "$CADDY_CONFIG_FILE" 2>&1; then
        log_message "ERROR" "Caddy 配置验证失败"
        
        # 使用优化后的验证处理
        if ! handle_validation_failure "$CADDY_CONFIG_FILE" "$skip_checks"; then
            log_message "FATAL" "配置验证失败，部署中止"
            return 1
        fi
    fi
    log_message "INFO" "Caddy 配置验证通过"
    
    # 检查 V2Ray 配置
    log_message "INFO" "验证 V2Ray 配置..."
    if ! v2ray test -c "$V2RAY_CONFIG_DIR/config.json" 2>&1; then
        log_message "ERROR" "V2Ray 配置验证失败"
        return 1
    fi
    log_message "INFO" "V2Ray 配置验证通过"
    
    return 0
}

deploy_services() {
    log_message "INFO" "部署服务..."
    
    # 重新加载 Caddy 配置
    if ! caddy reload --config "$CADDY_CONFIG_FILE"; then
        log_message "ERROR" "Caddy 配置重载失败"
        return 1
    fi
    log_message "INFO" "Caddy 配置已更新"
    
    # 重启 V2Ray 服务
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart v2ray || {
            log_message "WARN" "无法通过 systemctl 重启 V2Ray，使用备用方案"
            pkill v2ray || true
            sleep 1
            v2ray -c "$V2RAY_CONFIG_DIR/config.json" &
        }
    else
        pkill v2ray || true
        sleep 1
        v2ray -c "$V2RAY_CONFIG_DIR/config.json" &
    fi
    
    log_message "INFO" "V2Ray 服务已更新"
    
    return 0
}

# ==================== 主流程 ====================

main() {
    # 初始化验证模块
    init_validation_module
    
    # 检查依赖
    if ! check_dependencies; then
        exit 1
    fi
    
    case "${1:-deploy}" in
        deploy)
            shift
            setup_environment
            generate_v2ray_config
            generate_caddy_config
            validate_deployment "$@"
            if ! deploy_services; then
                log_message "ERROR" "服务部署失败"
                exit 1
            fi
            log_message "INFO" "V2Ray 部署成功"
            ;;
            
        dev)
            # 开发模式快捷方式
            export V2RAY_ENV="development"
            shift
            setup_environment
            configure_dev_mode  # 手动触发开发模式配置
            generate_v2ray_config
            generate_caddy_config
            if ! validate_deployment --skip-dns-check --skip-tls-check; then
                log_message "ERROR" "配置验证失败"
                exit 1
            fi
            deploy_services
            log_message "INFO" "V2Ray 开发部署成功"
            ;;
            
        validate-only)
            shift
            local skip_checks=""
            [[ $# -gt 0 ]] && skip_checks=$(parse_cli_args "$@")
            
            generate_caddy_config
            validate_deployment "$skip_checks"
            log_message "INFO" "配置验证完成"
            ;;
            
        help|--help|-h)
            cat << EOF
用法: $0 [deploy|dev|validate-only] [选项]

命令:
  deploy          标准部署（生产环境）
  dev             开发模式部署（自动配置本地环境）
  validate-only   仅验证配置

选项:
  --skip-dns-check    跳过 DNS 检查（开发环境）
  --skip-tls-check    跳过 TLS 检查（开发环境）
  --force-deploy      强制部署（跳过所有检查）
  --no-auto-fix       禁用自动修正

环境变量:
  V2RAY_ENV         环境标识 (production|development)
  CLOUDFLARE_API_TOKEN Cloudflare API 令牌

EOF
            ;;
            
        *)
            log_message "ERROR" "未知命令: $1"
            log_message "INFO" "使用 --help 查看帮助"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
```

## 示例三：测试集成

```bash
#!/bin/bash
# 测试 Caddy 验证优化模块

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CADDY_VALIDATOR="$SCRIPT_DIR/caddy-validation-optimizer.sh"

# 设置环境
export V2RAY_ENV="development"
export LOG_FILE="/tmp/test-v2ray-deploy.log"

# 源文件
source "$CADDY_VALIDATOR"

# 创建测试配置文件
TEST_CONFIG="/tmp/test-Caddyfile"

echo "=== 测试场景 1: 占位符域名 ==="
cat > "$TEST_CONFIG" << 'EOF'
:443 {
    reverse_proxy localhost:8080
}
EOF

# 模拟验证失败（替换为占位符）
sed -i 's/localhost:8080/yourdomain.com/' "$TEST_CONFIG"

# 需要手动加载错误日志
CADDY_ERROR_LOG=$(caddy validate --config "$TEST_CONFIG" 2>&1)

echo "诊断代码: $(analyze_validation_error "$CADDY_ERROR_LOG")"

echo ""
echo "=== 测试场景 2: DNS 问题 ==="
cat > "$TEST_CONFIG" << 'EOF'
:443 {
    reverse_proxy localhost:8080
}
EOF

CADDY_ERROR_LOG="resolver error: dialing: lookup yourdomain.com on 8.8.8.8:53: no such host"
echo "诊断代码: $(analyze_validation_error "$CADDY_ERROR_LOG")"

echo ""
echo "=== 测试场景 3: Cloudflare API 问题 ==="
CADDY_ERROR_LOG="cloudflare: API error: 10000: Invalid API token provided"
echo "诊断代码: $(analyze_validation_error "$CADDY_ERROR_LOG")"

echo ""
echo "=== 测试场景 4: 版本兼容性 ==="
CADDY_ERROR_LOG="Error parsing Caddyfile: json: unknown field \"admin_disabled\""
echo "诊断代码: $(analyze_validation_error "$CADDY_ERROR_LOG")"

echo ""
echo "=== 测试自动修正 ==="
# 创建带占位符的测试配置
cat > "$TEST_CONFIG" << EOF
:443 {
    reverse_proxy localhost:8080
}
EOF

# 模拟错误日志
export CADDY_ERROR_LOG="dns error: lookup yourdomain.com on 8.8.8.8:51: no such host"

# 解析参数
SKIP_CHECKS=$(parse_cli_args "--skip-dns-check")

# 处理验证失败
echo "处理验证失败..."
if ! handle_validation_failure "$TEST_CONFIG" "$SKIP_CHECKS"; then
    echo "处理失败"
else
    echo "处理成功"
fi

echo ""
echo "=== 测试命令行参数解析 ==="
SKIP_CHECKS=$(parse_cli_args "--dev-mode" "--skip-dns-check")
echo "解析结果: $SKIP_CHECKS"

echo ""
echo "=== 测试日志输出 ==="
log_message "INFO" "测试日志消息"
log_message "WARN" "测试警告消息"
log_message "ERROR" "测试错误消息"

echo ""
echo "测试完成！查看 $LOG_FILE 获取日志"
```

## 集成检查清单

### [ ] 集成前准备

- [ ] 复制 `caddy-validation-optimizer.sh` 到部署脚本同目录
- [ ] 确保 Caddy 已正确安装
- [ ] 测试 `caddy validate` 命令可用

### [ ] 代码集成

- [ ] 在脚本顶部添加 `source` 语句
- [ ] 替换原始验证逻辑为 `handle_validation_failure`
- [ ] 确保命令行参数正确传递

### [ ] 测试验证

- [ ] 测试占位符域名自动修正
- [ ] 测试 DNS 检查跳过功能
- [ ] 测试强制部署功能
- [ ] 测试开发模式配置
- [ ] 检查日志输出格式

### [ ] 生产部署

- [ ] 设置 `V2RAY_ENV=production`
- [ ]移除所有临时参数
- [ ] 验证日志写入 `/var/log/v2ray-deploy.log`
- [ ] 测试完整部署流程

## 故障排查

### 问题：`handle_validation_failure` 未找到

**解决**：确认 `source` 语句在变量定义之前
```bash
#!/bin/bash
# 错误：变量在 source 之前
# SCRIPT_DIR=...
source "$SCRIPT_DIR/caddy-validation-optimizer.sh"
# 正确：先 source
```

### 问题：参数未生效

**解决**：检查 `parse_cli_args` 调用位置
```bash
# 在 handle_validation_failure 之前必须调用
SKIP_CHECKS=$(parse_cli_args "$@")
```

### 问题：日志未写入

**解决**：检查日志目录权限
```bash
# 确保目录可写
sudo mkdir -p /var/log
sudo chmod 666 /var/log/v2ray-deploy.log
# 或使用自定义日志路径
export LOG_FILE="/tmp/v2ray-deploy.log"
```

## 扩展功能

### 添加自定义诊断类型

在 `analyze_validation_error` 函数中添加：

```bash
# 添加自定义诊断
if echo "$error_log" | grep -qiE "(custom_error)"; then
    log_message "INFO" "诊断结果: 自定义问题"
    echo "5"  # 返回自定义诊断码
    return
fi
```

### 添加自定义自动修正

在 `attempt_auto_fix` 函数中添加：

```bash
case "$diagnostic_code" in
    # ... 现有代码 ...
    
    5)  # 自定义诊断码
        # 自定义修正逻辑
        log_message "INFO" "应用自定义修正"
        # ...
        ;;
esac
```
