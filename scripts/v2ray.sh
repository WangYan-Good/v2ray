#!/bin/bash
# v2ray.sh - 兼容性 stub
# 获取脚本真实路径（解析符号链接）
get_real_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [[ -h "$source" ]]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

SCRIPT_DIR="$(get_real_script_dir)"
WORK_DIR="$(dirname "$SCRIPT_DIR")"

# 新架构路径
NEW_ENTRY="$WORK_DIR/src/bin/v2ray"

# 检查新主入口是否存在
if [[ ! -f "$NEW_ENTRY" ]]; then
    echo "ERROR: New entry point not found: $NEW_ENTRY" >&2
    exit 1
fi

# 执行新主入口，传递所有参数
exec "$NEW_ENTRY" "$@"
