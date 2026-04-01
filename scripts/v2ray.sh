#!/bin/bash
# v2ray.sh - 兼容性 stub，重定向到新架构主入口
# 用于保持与旧版本的向后兼容性

# =============================================================================
# 环境设置
# =============================================================================

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(dirname "$SCRIPT_DIR")"

# 新架构路径
NEW_ENTRY="$WORK_DIR/src/bin/v2ray"
LEGACY_SRC="$WORK_DIR/src"

# =============================================================================
# 依赖检查
# =============================================================================

# 检查新主入口是否存在
if [[ ! -f "$NEW_ENTRY" ]]; then
    echo "ERROR: New entry point not found: $NEW_ENTRY" >&2
    echo "Attempting to use legacy source files..." >&2
    
    # 尝试使用旧版文件
    if [[ -d "$LEGACY_SRC" ]]; then
        echo "WARNING: Using legacy source files (backward compatibility mode)" >&2
        ARGS=$@
        IS_SH_DIR="$LEGACY_SRC"
        . "$LEGACY_SRC/init.sh"
        exit $?
    else
        echo "FATAL: No source files found" >&2
        exit 1
    fi
fi

# =============================================================================
# 重定向到新主入口
# =============================================================================

# 检查 bash 版本
if [[ -z "$BASH_VERSION" ]]; then
    echo "ERROR: This script requires bash" >&2
    exit 1
fi

# 执行新主入口，传递所有参数
exec "$NEW_ENTRY" "$@"
