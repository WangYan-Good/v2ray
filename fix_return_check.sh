#!/bin/bash

# 修复脚本：为所有 auto_deploy_vps_architecture 调用添加返回值检查
# 日期：2026-03-27
# 问题：调用 auto_deploy_vps_architecture 后未检查返回值，导致配置验证失败时仍继续执行

set -e

CORE_FILE="/home/node/.openclaw/v2ray/src/core.sh"
BACKUP_FILE="${CORE_FILE}.bak.$(date +%Y%m%d_%H%M%S)"

# 备份原文件
echo "备份原文件到 $BACKUP_FILE"
cp "$CORE_FILE" "$BACKUP_FILE"

# 创建临时文件
TMP_FILE=$(mktemp)

# 处理逻辑：
# 1. 查找所有 [[ $IS_JSON_FILE && -f "$IS_JSON_FILE" && -n "$web_server" ]] && auto_deploy_vps_architecture "$IS_JSON_FILE" "$web_server" "true"
# 2. 替换为带返回值检查的版本
# 3. 同时处理 add 调用，确保其返回值也被检查

cat "$CORE_FILE" | awk '
BEGIN {
    in_case = 0
    skip_next = 0
    last_add_line = ""
}

# 检测是否在 case 语句中
/^[[:space:]]*[0-9]+)[[:space:]]*#/ {
    in_case = 1
    skip_next = 0
    last_add_line = ""
}

# 记录 add 调用的行（需要先修复 add 调用的返回值检查）
/^[[:space:]]*add[[:space:]]+\$NET/ {
    # 检查是否已经包裹在 if ! ...; then 中
    if ($0 !~ /^[[:space:]]*if[[:space:]]+!/) {
        # 这是一个需要修复的 add 调用
        # 保存缩进
        match($0, /^[[:space:]]*/)
        indent = substr($0, RSTART, RLENGTH)
        # 提取参数
        rest = substr($0, index($0, "add"))
        # 输出修复后的版本
        print indent "if ! " rest "; then"
        print indent "    err \"修改配置失败\""
        print indent "    return 1"
        print indent "fi"
        skip_next = 1
        next
    }
}

# 跳过下一个 auto_deploy_vps_architecture 调用（因为 add 失败时不应该执行它）
skip_next == 1 && /auto_deploy_vps_architecture/ {
    # 修复这个调用
    match($0, /^[[:space:]]*/)
    indent = substr($0, RSTART, RLENGTH)

    # 提取条件部分（如果有的话）
    if ($0 ~ /^\[\[.*\]\][[:space:]]*&&[[:space:]]*auto_deploy_vps_architecture/) {
        # 提取条件
        match($0, /^\[\[.*\]\]/)
        condition = substr($0, RSTART, RLENGTH)
        rest = substr($0, RSTART + RLENGTH)

        # 移除 && 和 auto_deploy_vps_architecture 之间的空格
        gsub(/^[[:space:]]*&&[[:space:]]*/, "", rest)

        # 提取函数调用
        match(rest, /auto_deploy_vps_architecture.*$/)
        func_call = substr(rest, RSTART, RLENGTH)

        print indent condition " && {"
        print indent "    if ! " func_call "; then"
        print indent "        err \"VPS 架构部署失败\""
        print indent "        return 1"
        print indent "    fi"
        print indent "}"
    } else {
        # 直接调用
        print indent "if ! " $0 "; then"
        print indent "    err \"VPS 架构部署失败\""
        print indent "    return 1"
        print indent "fi"
    }

    skip_next = 0
    next
}

# 跳过已经被修复的行
skip_next == 1 {
    next
}

# 查找并修复其他地方的 auto_deploy_vps_architecture 调用
/auto_deploy_vps_architecture/ && !/if ! auto_deploy_vps_architecture/ && !/if ! \$\!/ {
    match($0, /^[[:space:]]*/)
    indent = substr($0, RSTART, RLENGTH)

    # 如果已经有条件包裹
    if ($0 ~ /^\[\[.*\]\][[:space:]]*&&[[:space:]]*auto_deploy_vps_architecture/) {
        match($0, /^\[\[.*\]\]/)
        condition = substr($0, RSTART, RLENGTH)
        rest = substr($0, RSTART + RLENGTH)

        gsub(/^[[:space:]]*&&[[:space:]]*/, "", rest)

        match(rest, /auto_deploy_vps_architecture.*$/)
        func_call = substr(rest, RSTART, RLENGTH)

        print indent condition " && {"
        print indent "    if ! " func_call "; then"
        print indent "        err \"VPS 架构部署失败\""
        print indent "        return 1"
        print indent "    fi"
        print indent "}"
    } else {
        # 直接调用
        print indent "if ! " $0 "; then"
        print indent "    err \"VPS 架构部署失败\""
        print indent "    return 1"
        print indent "fi"
    }
    next
}

# 其他行原样输出
{
    print
}
' > "$TMP_FILE"

# 检查临时文件是否为空
if [[ ! -s "$TMP_FILE" ]]; then
    echo "错误：临时文件为空"
    rm -f "$TMP_FILE"
    exit 1
fi

# 替换原文件
mv "$TMP_FILE" "$CORE_FILE"

echo "✅ 修复完成！"
echo "已修复所有 auto_deploy_vps_architecture 调用的返回值检查"
echo "备份文件: $BACKUP_FILE"