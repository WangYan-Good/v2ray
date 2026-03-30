# Caddy 配置验证优化模块

## 概述

本模块实现了 V2Ray 部署脚本中 Caddy 配置验证的智能诊断与自动修正功能，确保所有环境（生产、测试、开发）采用统一的严格标准。

## 核心特性

### 1. 环境一致性原则
- 所有环境下验证策略完全一致
- 关键安全问题（DNS、TLS、Cloudflare）严格中止
- 开发模式提供显式覆盖标志支持

### 2. 智能诊断系统
| 诊断码 | 问题类型 | 是否可自动修正 |
|--------|----------|----------------|
| 0 | 其他配置问题 | ❌ 严格中止 |
| 1 | DNS 配置问题 | ❌ 严格中止 |
| 2 | Cloudflare API 问题 | ❌ 严格中止 |
| 3 | 占位符域名 | ✅ 自动替换 |
| 4 | Caddy 版本兼容性 | ❌ 严格中止 |

### 3. 自动修正机制
- **仅处理安全场景**：仅自动替换占位符域名
- **支持替换的域名**：
  - `yourdomain.com`
  - `example.com`
  - `example.org`
  - `placeholder.com`
- **替换目标**：`hostname.local`

### 4. 命令行覆盖支持
| 参数 | 说明 | 风险等级 |
|------|------|----------|
| `--skip-dns-check` | 跳过 DNS 检查 | ⚠️ 中等 |
| `--skip-tls-check` | 跳过 TLS 检查 | ⚠️ 中等 |
| `--force-deploy` | 强制部署 | 🔴 高 |
| `--dev-mode` | 开发模式（自动配置） | ✅ 安全 |
| `--no-auto-fix` | 禁用自动修正 | ✅ 安全 |

## 使用方法

### 1. 在现有脚本中集成

```bash
# 在 v2ray-vps-auto-deploy.sh 顶部添加
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/caddy-validation-optimizer.sh"

# 解析命令行参数
SKIP_CHECKS=$(parse_cli_args "$@")

# 部署流程中进行配置验证
if ! caddy validate --config /etc/caddy/Caddyfile 2>&1; then
    handle_validation_failure "/etc/caddy/Caddyfile" "$SKIP_CHECKS"
    exit $?
fi
```

### 2. 基础使用示例

```bash
# 基础验证
if ! caddy validate --config /etc/caddy/Caddyfile 2>&1; then
    SKIP_CHECKS=$(parse_cli_args "$@")
    handle_validation_failure "/etc/caddy/Caddyfile" "$SKIP_CHECKS"
    exit $?
fi
```

### 3. 命令行参数使用

```bash
# 开发模式（推荐用于本地测试）
./v2ray-vps-auto-deploy.sh --dev-mode

# 强制部署（生产环境需谨慎）
./v2ray-vps-auto-deploy.sh --force-deploy

# 跳过 DNS 检查（开发环境）
./v2ray-vps-auto-deploy.sh --skip-dns-check

# 禁用自动修正
./v2ray-vps-auto-deploy.sh --no-auto-fix
```

### 4. 环境变量配置

```bash
# 设置环境标识
export V2RAY_ENV="production"  # production|testing|development
export LOG_FILE="/var/log/v2ray-deploy.log"
```

## 诊断函数详解

### `analyze_validation_error`

```bash
# 输入：错误日志内容
analyze_validation_error "DNS resolution failed: yourdomain.com"

# 输出：诊断码（0-4）
# 0 = 其他问题
# 1 = DNS 配置问题
# 2 = Cloudflare API 问题
# 3 = 占位符域名
# 4 = Caddy 版本兼容性
```

### `attempt_auto_fix`

```bash
# 仅处理占位符域名（code=3）
attempt_auto_fix "/etc/caddy/Caddyfile" 3

# 输出：true/false
```

### `handle_validation_failure`

```bash
# 统一验证失败处理
handle_validation_failure "/etc/caddy/Caddyfile" "--skip-dns-check"
```

## 集成到 v2ray-vps-auto-deploy.sh

### 修改步骤

1. **在脚本顶部添加源文件**：
```bash
# V2Ray 部署脚本头部
#!/bin/bash
set -euo pipefail

# 引入 Caddy 验证优化模块
CADDY_VALIDATOR="${BASH_SOURCE[0]%/*}/caddy-validation-optimizer.sh"
if [[ -f "$CADDY_VALIDATOR" ]]; then
    source "$CADDY_VALIDATOR"
fi
```

2. **在配置验证处添加处理逻辑**：
```bash
# 原代码：
# echo "[ERROR] Caddy 配置验证失败"
# read -p "是否继续？[y/N] " -n 1 -r

# 替换为：
echo "[ERROR] Caddy 配置验证失败"

SKIP_CHECKS=$(parse_cli_args "$@")
if ! handle_validation_failure "/etc/caddy/Caddyfile" "$SKIP_CHECKS"; then
    echo "[FATAL] 部署中止"
    exit 1
fi
```

3. **确保主流程传递参数**：
```bash
# 在部署函数开始处
main() {
    SKIP_CHECKS=$(parse_cli_args "$@")
    # ... 其他代码
}
```

## 日志格式

所有日志写入 `/var/log/v2ray-deploy.log`：

```
[2026-03-28 04:46:00] [INFO]  [v2ray-deploy] Caddy 验证优化模块初始化完成
[2026-03-28 04:46:00] [INFO]  [v2ray-deploy] 运行环境: production
[2026-03-28 04:46:01] [WARN]  [v2ray-deploy] 检测到占位符域名 (yourdomain.com)
[2026-03-28 04:46:02] [INFO]  [v2ray-deploy] 自动修正成功: 占位符已替换为 hostname.local
[2026-03-28 04:46:03] [ERROR] [v2ray-deploy] DNS 配置问题中止部署
```

## 安全策略

### 关键保护机制

1. **仅自动修正占位符域名**
   - 不修改 DNS 配置
   - 不修改 TLS 证书设置
   - 不修改 Cloudflare API 令牌

2. **严格中止条件**：
   - DNS 配置问题 → 需 `--skip-dns-check` 或 `--force-deploy`
   - TLS 证书问题 → 需 `--skip-tls-check` 或 `--force-deploy`
   - Cloudflare API 问题 → 需 `--force-deploy`
   - 复杂配置错误 → 仅 `--force-deploy`

3. **开发模式自动配置**：
   - 使用 `--dev-mode` 自动设置本地域名
   - 自动替换占位符为 `hostname.local`
   - 自动跳过 DNS 和 TLS 检查

## 故障排查

### 问题：验证失败但无明确错误

**检查**：
```bash
# 查看详细错误日志
cat /var/log/v2ray-deploy.log

# 检查 Caddy 配置
caddy validate --config /etc/caddy/Caddyfile --detail

# 手动运行分析
source caddy-validation-optimizer.sh
analyze_validation_error "$(caddy validate --config /etc/caddy/Caddyfile 2>&1)"
```

### 问题：占位符未自动替换

**检查**：
1. 确认使用的是 `--dev-mode` 或未使用 `--no-auto-fix`
2. 检查配置文件是否包含标准占位符
3. 查看日志确认替换过程

### 问题：强制部署模式不生效

**检查**：
```bash
# 确保参数正确传递
./v2ray-vps-auto-deploy.sh --force-deploy

# 检查解析后的参数
SKIP_CHECKS=$(parse_cli_args "$@")
echo "$SKIP_CHECKS"  # 应包含 --force-deploy
```

## 代码结构

```
caddy-validation-optimizer.sh
├── 配置常量
├── 日志记录模块 (log_message, IDENTIFY_ENVIRONMENT)
├── 初始化函数 (init_validation_module)
├── 智能诊断分析 (analyze_validation_error)
├── 自动修正函数 (attempt_auto_fix)
├── 统一验证处理 (handle_validation_failure)
├── 命令行参数解析 (parse_cli_args)
├── 辅助函数
│   ├── configure_dev_mode
│   ├── validate_caddy_config
│   ├── check_dependencies
│   └── usage
└── 主流程入口 (main)
```

## 最佳实践

1. **生产环境**：使用默认配置，不添加任何跳过参数
2. **测试环境**：可使用 `--skip-tls-check` 进行快速测试
3. **开发环境**：推荐使用 `--dev-mode` 自动配置
4. **CI/CD**：务必使用 `--no-auto-fix` 确保配置正确性

## 更新日志

- **v1.0.0** (2026-03-28)
  - 初始版本
  - 实现智能诊断系统
  - 支持占位符域名自动修正
  - 实现命令行覆盖机制
