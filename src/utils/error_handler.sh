#!/bin/bash
# error_handler.sh - 增强版错误处理框架
# 提供统一错误处理、重试机制、安全文件操作和清理函数注册

# =============================================================================
# 文件名称: error_handler.sh
# 功能描述: 增强版错误处理框架，提供统一错误处理和安全操作
# 作者: Developer
# 版本: 1.0
# 创建日期: 2026-03-31
# =============================================================================

##
## 统一错误码定义（扩展现有 error.sh）
##
# 继承 src/error.sh 中的错误码定义
# ERR_SUCCESS=0
# ERR_GENERAL=1
# ERR_INVALID_ARGS=2
# ERR_PERMISSION_DENIED=3
# ERR_FILE_NOT_FOUND=4
# ERR_NETWORK=5
# ERR_DEPENDENCY=6
# ERR_CONFIG=7
# ERR_SERVICE=8

# 新增错误码
readonly ERR_CLEANUP=9
readonly ERR_RETRY_EXHAUSTED=10
readonly ERR_SERVICE_ACTION=11

# =============================================================================
# 全局状态变量
## =============================================================================

# 错误发生标志
ERROR_OCCURRED=false

# 清理函数注册表（数组）
CLEANUP_FUNCS=()

# =============================================================================
# 基础工具函数
## =============================================================================

##
## 获取调用栈信息
## @param: [max_frames] 最大显示帧数（可选，默认10）
## @return: 调用栈字符串
##
get_call_stack() {
    local max_frames="${1:-10}"
    local stack=""
    local i

    for ((i=0; i<max_frames && i<${#BASH_SOURCE[@]}; i++)); do
        if [[ $i -eq 0 ]]; then
            continue  # 跳过当前函数
        fi

        local line="${BASH_LINENO[$((i-1))]}"
        local source="${BASH_SOURCE[$i]}"
        local func="${FUNCNAME[$i]}"

        if [[ -n "$func" && "$func" != "main" ]]; then
            stack+="  at $func($source:$line)\n"
        fi
    done

    echo -e "$stack"
}

##
## 获取调用栈摘要
## @return: 调用栈摘要字符串
##
get_call_summary() {
    local summary=""
    local i

    for ((i=1; i<${#BASH_SOURCE[@]} && i<10; i++)); do
        local func="${FUNCNAME[$i]}"
        local line="${BASH_LINENO[$((i-1))]}"
        local source="${BASH_SOURCE[$i]#*src/}"

        if [[ -n "$func" && "$func" != "main" && "$func" != "get_call_stack" ]]; then
            summary+="${func}:${source}:${line}"
            if [[ $i -lt ${#BASH_SOURCE[@]}-1 ]]; then
                summary+=" <- "
            fi
        fi
    done

    echo "$summary"
}

# =============================================================================
# 清理函数注册机制
## =============================================================================

##
## 注册清理函数
## @param: cleanup_func 清理函数名
## @param: ... 添加清理函数时的参数（可选）
## @return: 0 成功
## @see: execute_cleanup
##
register_cleanup() {
    local func_name="$1"
    shift

    if [[ -z "$func_name" ]]; then
        log_error "register_cleanup: 清理函数名不能为空"
        return $ERR_INVALID_ARGS
    fi

    # 检查函数是否存在
    if ! declare -f "$func_name" >/dev/null 2>&1; then
        log_error "register_cleanup: 清理函数 '$func_name' 未定义"
        return $ERR_GENERAL
    fi

    # 注册清理函数及其参数
    CLEANUP_FUNCS+=("$(printf '%q' "$func_name")")
    for arg in "$@"; do
        CLEANUP_FUNCS+=("$(printf '%q' "$arg")")
    done
    CLEANUP_FUNCS+=("__SEP__")  # 分隔符

    log_debug "已注册清理函数: $func_name"
    return 0
}

##
## 执行所有已注册的清理函数
## @return: 0 成功（即使某些清理函数失败）
##
execute_cleanup() {
    local has_error=false
    local i=0

    log_info "开始执行清理函数..."

    while [[ $i -lt ${#CLEANUP_FUNCS[@]} ]]; do
        local func_name="${CLEANUP_FUNCS[$i]}"

        if [[ "$func_name" == "__SEP__" ]]; then
            ((i++))
            continue
        fi

        # 收集参数
        local args=()
        ((i++))
        while [[ $i -lt ${#CLEANUP_FUNCS[@]} && "${CLEANUP_FUNCS[$i]}" != "__SEP__" ]]; do
            args+=("${CLEANUP_FUNCS[$i]}")
            ((i++))
        done

        # 执行清理函数
        if [[ $i -lt ${#CLEANUP_FUNCS[@]} ]] || [[ "${CLEANUP_FUNCS[$((i))]}" == "__SEP__" ]]; then
            # 恢复索引到参数位置
            local temp_i=$((i - ${#args[@]} - 1))
            if ! "${args[0]}" "${args[@]:1}" 2>/dev/null; then
                log_warn "清理函数 '$func_name' 执行失败"
                has_error=true
            fi
        fi

        ((i++))
    done

    # 清空清理函数列表
    CLEANUP_FUNCS=()

    if [[ "$has_error" == "true" ]]; then
        log_error "部分清理函数执行失败"
        return $ERR_CLEANUP
    fi

    log_info "清理函数执行完成"
    return 0
}

# =============================================================================
# 增强版错误处理
## =============================================================================

##
## 增强版错误退出函数
## 提供可恢复错误、调用栈追踪和清理函数执行
##
## @param: message 错误信息
## @param: [code] 错误码（可选，默认 ERR_GENERAL）
## @param: [recoverable] 是否为可恢复错误（可选，默认 false）
## @return: 如果 recoverable=true，返回错误码；否则退出脚本
## @see: register_cleanup execute_cleanup
##
error_exit() {
    local message="$1"
    local code="${2:-$ERR_GENERAL}"
    local recoverable="${3:-false}"

    # 设置错误标志
    ERROR_OCCURRED=true

    # 记录详细错误信息
    log_error "========================================"
    log_error "错误详情: $message"
    log_error "错误码: $code"
    log_error "调用栈摘要: $(get_call_summary)"
    log_error "调用栈: $(get_call_stack 15)"
    log_error "========================================"

    # 执行清理函数
    if [[ ${#CLEANUP_FUNCS[@]} -gt 0 ]]; then
        execute_cleanup
    fi

    # 根据错误类型决定是否退出
    if [[ "$recoverable" == "true" ]]; then
        log_warn "可恢复错误，继续执行..."
        return $code
    else
        log_error "不可恢复错误，程序退出"
        exit $code
    fi
}

# =============================================================================
# 重试机制
## =============================================================================

##
## 带重试机制的命令执行（指数退避）
## 自动重试失败的命令，最多 3 次，采用指数退避策略
##
## @param: max_attempts 最大重试次数（可选，默认 3）
## @param: delay 初始延迟秒数（可选，默认 1）
## @param: ... 命令及其参数
## @return: 0 成功，否则返回失败码
## @exit: 如果重试耗尽，调用 error_exit
## @see: error_exit
##
retry_command() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    shift 2

    # 检查是否有命令
    if [[ $# -eq 0 ]]; then
        log_error "retry_command: 没有指定命令"
        error_exit "retry_command: 没有指定命令" $ERR_INVALID_ARGS false
    fi

    local cmd=("$@")
    local attempt=0

    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        log_info "执行命令 [$attempt/$max_attempts]: ${cmd[*]}"

        # 执行命令
        if "${cmd[@]}"; then
            if [[ $attempt -gt 1 ]]; then
                log_info "命令成功，重试次数: $((attempt-1))"
            fi
            return 0
        fi

        # 检查是否还有重试机会
        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "命令失败，${delay}秒后第${attempt}次重试"
            sleep "$delay"
            # 指数退避：1, 2, 4, 8, ...
            delay=$((delay * 2))
        fi
    done

    # 重试耗尽
    log_error "命令重试失败 [$attempt-1/$max_attempts]: ${cmd[*]}"
    error_exit "命令重试失败: ${cmd[*]}" $ERR_RETRY_EXHAUSTED false
}

##
## 带超时的重试命令
## 在 retry_command 基础上增加超时控制
##
## @param: max_attempts 最大重试次数（可选，默认 3）
## @param: delay 初始延迟秒数（可选，默认 1）
## @param: timeout 单次命令超时时间（可选，默认 60）
## @param: ... 命令及其参数
## @return: 0 成功，否则返回失败码
##
retry_command_with_timeout() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    local timeout="${3:-60}"
    shift 3

    # 包装命令并添加超时
    local wrapped_cmd=("timeout" "$timeout" "${@}")

    retry_command "$max_attempts" "$delay" "${wrapped_cmd[@]}"
}

# =============================================================================
# 安全文件操作包装器
## =============================================================================

##
## 安全删除文件/目录
## 检查文件存在性、权限和路径安全性
##
## @param: file 文件或目录路径
## @param: ... 其他参数传递给 rm
## @return: 0 成功
## @see: error_exit
##
safe_rm() {
    local path="$1"
    shift

    if [[ -z "$path" ]]; then
        log_error "safe_rm: 路径不能为空"
        error_exit "safe_rm: 路径不能为空" $ERR_INVALID_ARGS false
    fi

    # 检查路径是否为空
    if [[ "$path" == "" ]]; then
        log_error "safe_rm: 不能删除空路径"
        error_exit "safe_rm: 不能删除空路径" $ERR_INVALID_ARGS false
    fi

    # 检查是否是根目录
    if [[ "$path" == "/" ]]; then
        log_error "safe_rm: 不能删除根目录"
        error_exit "safe_rm: 不能删除根目录" $ERR_GENERAL false
    fi

    # 检查路径是否包含危险模式（可配置）
    if [[ "$path" == *".."* ]] && [[ "$path" != *"/../*" && "$path" != "../"* ]]; then
        # 检查是否是相对路径中的 ..
        if [[ "$path" == *"../"* ]] || [[ "$path" == *".." ]]; then
            log_warn "safe_rm: 路径包含 '..'，将进行安全检查: $path"
        fi
    fi

    # 检查文件是否存在
    if [[ ! -e "$path" ]]; then
        log_info "safe_rm: 文件不存在，跳过删除: $path"
        return 0
    fi

    # 记录删除操作
    log_info "safe_rm: 删除文件/目录: $path"
    if [[ -d "$path" ]]; then
        log_debug "safe_rm: 这是一个目录"
    elif [[ -f "$path" ]]; then
        log_debug "safe_rm: 这是一个文件"
    fi

    # 执行删除
    if rm -rf "$path" "$@"; then
        log_info "safe_rm: 删除成功: $path"
        return 0
    else
        log_error "safe_rm: 删除失败: $path"
        error_exit "safe_rm: 删除失败: $path" $ERR_GENERAL true
    fi
}

##
## 安全创建目录
## 检查权限、递归创建和存在性
##
## @param: dir 目录路径
## @param: ... 其他参数传递给 mkdir
## @return: 0 成功
## @see: error_exit
##
safe_mkdir() {
    local dir="$1"
    shift

    if [[ -z "$dir" ]]; then
        log_error "safe_mkdir: 路径不能为空"
        error_exit "safe_mkdir: 路径不能为空" $ERR_INVALID_ARGS false
    fi

    # 检查目录是否已存在
    if [[ -d "$dir" ]]; then
        log_info "safe_mkdir: 目录已存在: $dir"
        return 0
    fi

    # 检查父目录是否存在
    local parent_dir
    parent_dir="$(dirname "$dir")"
    if [[ ! -d "$parent_dir" ]]; then
        log_info "safe_mkdir: 父目录不存在，正在创建: $parent_dir"
        safe_mkdir "$parent_dir"
    fi

    # 记录创建操作
    log_info "safe_mkdir: 创建目录: $dir"

    # 执行创建
    if mkdir -p "$dir" "$@"; then
        log_info "safe_mkdir: 创建成功: $dir"
        return 0
    else
        log_error "safe_mkdir: 创建失败: $dir"
        error_exit "safe_mkdir: 创建失败: $dir" $ERR_GENERAL true
    fi
}

##
## 安全复制文件/目录
## 检查源文件存在性和目标目录权限
##
## @param: src 源路径
## @param: dst 目标路径
## @param: ... 其他参数传递给 cp
## @return: 0 成功
## @see: error_exit
##
safe_cp() {
    local src="$1"
    local dst="$2"
    shift 2

    if [[ -z "$src" ]]; then
        log_error "safe_cp: 源路径不能为空"
        error_exit "safe_cp: 源路径不能为空" $ERR_INVALID_ARGS false
    fi

    if [[ -z "$dst" ]]; then
        log_error "safe_cp: 目标路径不能为空"
        error_exit "safe_cp: 目标路径不能为空" $ERR_INVALID_ARGS false
    fi

    # 检查源文件是否存在
    if [[ ! -e "$src" ]]; then
        log_error "safe_cp: 源文件/目录不存在: $src"
        error_exit "safe_cp: 源文件/目录不存在: $src" $ERR_FILE_NOT_FOUND false
    fi

    # 确保目标目录存在
    local dst_dir
    dst_dir="$(dirname "$dst")"
    if [[ ! -d "$dst_dir" ]]; then
        log_info "safe_cp: 目标目录不存在，正在创建: $dst_dir"
        safe_mkdir "$dst_dir"
    fi

    # 记录复制操作
    log_info "safe_cp: 复制: $src -> $dst"
    if [[ -d "$src" ]]; then
        log_debug "safe_cp: 这是目录复制"
    fi

    # 执行复制
    if cp -rf "$src" "$dst" "$@"; then
        log_info "safe_cp: 复制成功: $src -> $dst"
        return 0
    else
        log_error "safe_cp: 复制失败: $src -> $dst"
        error_exit "safe_cp: 复制失败: $src -> $dst" $ERR_GENERAL true
    fi
}

##
## 安全移动文件/目录
## 结合复制和删除的安全操作
##
## @param: src 源路径
## @param: dst 目标路径
## @param: ... 其他参数传递给 mv
## @return: 0 成功
## @see: safe_cp safe_rm
##
safe_mv() {
    local src="$1"
    local dst="$2"
    shift 2

    # 首先尝试直接移动
    if mv -f "$src" "$dst" "$@" 2>/dev/null; then
        log_info "safe_mv: 移动成功: $src -> $dst"
        return 0
    fi

    # 移动失败，使用复制+删除
    log_info "safe_mv: 直接移动失败，使用复制+删除: $src -> $dst"
    safe_cp "$src" "$dst"
    safe_rm "$src"
    return 0
}

##
## 安全写入文件
## 确保目录存在，备份原文件（如果存在）
##
## @param: file 文件路径
## @param: content 文件内容
## @param: [backup] 是否备份原文件（可选，默认 true）
## @return: 0 成功
## @see: safe_mkdir
##
safe_write_file() {
    local file="$1"
    local content="$2"
    local backup="${3:-true}"

    if [[ -z "$file" ]]; then
        log_error "safe_write_file: 文件路径不能为空"
        error_exit "safe_write_file: 文件路径不能为空" $ERR_INVALID_ARGS false
    fi

    # 确保目录存在
    local dir
    dir="$(dirname "$file")"
    safe_mkdir "$dir"

    # 备份原文件
    if [[ -f "$file" && "$backup" == "true" ]]; then
        local backup_file="${file}.bak.$(date +%Y%m%d%H%M%S)"
        log_info "safe_write_file: 备份原文件: $file -> $backup_file"
        safe_cp "$file" "$backup_file"
    fi

    # 写入文件
    if echo -n "$content" > "$file"; then
        log_info "safe_write_file: 写入成功: $file"
        return 0
    else
        log_error "safe_write_file: 写入失败: $file"
        error_exit "safe_write_file: 写入失败: $file" $ERR_GENERAL true
    fi
}

# =============================================================================
# 服务状态检查和操作
## =============================================================================

##
## 检查服务状态
## @param: service 服务名称
## @return: 0 运行中, 1 停止, 2 未安装
##
service_status() {
    local service="$1"

    # 检查服务是否存在
    if ! systemctl list-unit-files "$service" 2>/dev/null | grep -q "$service"; then
        # 尝试另一种检查方式
        if [[ ! -f "/lib/systemd/system/$service" ]] && [[ ! -f "/etc/systemd/system/$service" ]]; then
            return 2
        fi
    fi

    # 检查服务是否正在运行
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        return 0
    fi

    # 检查进程是否存在
    if pidof "$service" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

##
## 检查服务状态并采取相应操作
## 自动处理服务启动/停止/重载
##
## @param: service 服务名称
## @param: action 操作: start|stop|restart|reload
## @param: [timeout] 超时时间（可选，默认 30）
## @return: 0 成功
## @see: error_exit
##
service_check_and_restart() {
    local service="$1"
    local action="${2:-restart}"
    local timeout="${3:-30}"

    if [[ -z "$service" ]]; then
        log_error "service_check_and_restart: 服务名称不能为空"
        error_exit "service_check_and_restart: 服务名称不能为空" $ERR_INVALID_ARGS false
    fi

    log_info "service_check_and_restart: 处理服务 '$service'，操作: $action"

    # 检查 systemctl 是否可用
    if ! command -v systemctl &>/dev/null; then
        log_warn "systemctl 不可用，尝试使用 service 命令"
        # 使用 service 命令
        case "$action" in
            start)
                service "$service" start
                ;;
            stop)
                service "$service" stop
                ;;
            restart)
                service "$service" restart
                ;;
            reload)
                service "$service" reload
                ;;
            *)
                log_error "未知操作: $action"
                error_exit "service_check_and_restart: 未知操作: $action" $ERR_GENERAL false
                ;;
        esac
        return $?
    fi

    # 检查服务是否存在
    local unit_file="/lib/systemd/system/${service}.service"
    if [[ ! -f "$unit_file" ]]; then
        unit_file="/etc/systemd/system/${service}.service"
    fi

    if [[ ! -f "$unit_file" ]]; then
        log_error "服务文件不存在: $unit_file"
        error_exit "服务文件不存在: $unit_file" $ERR_SERVICE false
    fi

    # 根据当前状态执行操作
    case "$action" in
        start)
            if service_status "$service" == 0; then
                log_info "服务 '$service' 已在运行"
                return 0
            fi
            log_info "启动服务: $service"
            if systemctl start "$service" 2>&1 | while IFS= read -r line; do
                log_debug "systemctl: $line"
            done; then
                log_info "服务启动成功: $service"
                return 0
            else
                log_error "服务启动失败: $service"
                error_exit "服务启动失败: $service" $ERR_SERVICE false
            fi
            ;;

        stop)
            if service_status "$service" == 1 || service_status "$service" == 2; then
                log_info "服务 '$service' 已停止"
                return 0
            fi
            log_info "停止服务: $service"
            if systemctl stop "$service" 2>&1 | while IFS= read -r line; do
                log_debug "systemctl: $line"
            done; then
                log_info "服务停止成功: $service"
                return 0
            else
                log_error "服务停止失败: $service"
                error_exit "服务停止失败: $service" $ERR_SERVICE false
            fi
            ;;

        restart)
            log_info "重启服务: $service"
            if systemctl restart "$service" 2>&1 | while IFS= read -r line; do
                log_debug "systemctl: $line"
            done; then
                log_info "服务重启成功: $service"
                return 0
            else
                log_error "服务重启失败: $service"
                error_exit "服务重启失败: $service" $ERR_SERVICE false
            fi
            ;;

        reload)
            log_info "重载服务: $service"
            if systemctl reload "$service" 2>&1 | while IFS= read -r line; do
                log_debug "systemctl: $line"
            done; then
                log_info "服务重载成功: $service"
                return 0
            else
                log_error "服务重载失败: $service"
                error_exit "服务重载失败: $service" $ERR_SERVICE false
            fi
            ;;

        *)
            log_error "未知操作: $action"
            error_exit "service_check_and_restart: 未知操作: $action" $ERR_GENERAL false
            ;;
    esac
}

##
## 重启服务并验证（带重试）
##
## @param: service 服务名称
## @param: max_attempts 重试次数（可选，默认 3）
## @return: 0 成功
## @see: service_check_and_restart retry_command
##
service_restart_with_retry() {
    local service="$1"
    local max_attempts="${2:-3}"

    service_check_and_restart "$service" restart

    # 验证服务正常运行
    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        if service_status "$service" == 0; then
            log_info "服务验证成功: $service"
            return 0
        fi
        log_warn "服务验证失败，等待中... (attempt $attempt/$max_attempts)"
        sleep 2
    done

    log_error "服务验证重复失败: $service"
    error_exit "服务验证重复失败: $service" $ERR_SERVICE false
}

# =============================================================================
# 上下文管理
## =============================================================================

##
## 创建错误处理上下文（用于子 Shell）
## 创建临时文件用于错误处理状态传递
##
## @param: context_name 上下文名称
## @return: 0 成功
##
create_error_context() {
    local context_name="$1"

    if [[ -z "$context_name" ]]; then
        error_exit "create_error_context: 上下文名称不能为空" $ERR_INVALID_ARGS false
    fi

    # 创建上下文目录
    local context_dir="/tmp/v2ray_error_context/${context_name}"
    safe_mkdir "$context_dir"

    # 初始化状态文件
    echo "false" > "$context_dir/error_occurred"
    echo "$$" > "$context_dir/pid"

    log_debug "创建错误处理上下文: $context_name"
    echo "$context_dir"
}

##
## 销毁错误处理上下文
##
## @param: context_dir 上下文目录路径
## @return: 0 成功
##
destroy_error_context() {
    local context_dir="$1"

    if [[ -z "$context_dir" ]]; then
        error_exit "destroy_error_context: 上下文目录不能为空" $ERR_INVALID_ARGS false
    fi

    safe_rm "$context_dir"
}

# =============================================================================
# 统计和诊断
## =============================================================================

##
## 显示当前清理函数列表
##
show_cleanup_registry() {
    if [[ ${#CLEANUP_FUNCS[@]} -eq 0 ]]; then
        echo "未注册任何清理函数"
        return 0
    fi

    echo "=== 注册的清理函数 ==="
    local i=0
    while [[ $i -lt ${#CLEANUP_FUNCS[@]} ]]; do
        local func_name="${CLEANUP_FUNCS[$i]}"
        if [[ "$func_name" == "__SEP__" ]]; then
            ((i++))
            continue
        fi
        echo "  - $func_name"
        ((i++))
        # 打印参数
        while [[ $i -lt ${#CLEANUP_FUNCS[@]} && "${CLEANUP_FUNCS[$i]}" != "__SEP__" ]]; do
            echo "      -> ${CLEANUP_FUNCS[$i]}"
            ((i++))
        done
        ((i++))  # 跳过 __SEP__
    done
    echo "========================"
}

# =============================================================================
# 测试和验证
## =============================================================================

##
## 运行错误处理框架自检
##
error_handler_self_test() {
    echo "=== 错误处理框架自检 ==="

    # 测试 1: 错误码定义
    echo "测试 1: 错误码定义"
    if [[ -n "$ERR_CLEANUP" ]]; then
        echo "  ✓ ERR_CLEANUP = $ERR_CLEANUP"
    else
        echo "  ✗ ERR_CLEANUP 未定义"
        return 1
    fi

    # 测试 2: get_call_stack
    echo "测试 2: 调用栈追踪"
    local stack
    stack=$(get_call_stack 5)
    if [[ -n "$stack" ]]; then
        echo "  ✓ 调用栈获取成功"
    else
        echo "  ✗ 调用栈获取失败"
        return 1
    fi

    # 测试 3: 安全目录创建
    echo "测试 3: 安全目录创建"
    local test_dir="/tmp/test_error_handler_$$"
    safe_mkdir "$test_dir"
    if [[ -d "$test_dir" ]]; then
        echo "  ✓ 目录创建成功"
        safe_rm "$test_dir"
    else
        echo "  ✗ 目录创建失败"
        return 1
    fi

    # 测试 4: 清理函数注册
    echo "测试 4: 清理函数注册"
    local test_file="/tmp/test_cleanup_$$"
    touch "$test_file"

    _test_cleanup_func() {
        rm -f "$test_file"
    }

    register_cleanup "_test_cleanup_func"
    if [[ ${#CLEANUP_FUNCS[@]} -gt 0 ]]; then
        echo "  ✓ 清理函数注册成功"
    else
        echo "  ✗ 清理函数注册失败"
        return 1
    fi

    execute_cleanup
    if [[ ! -f "$test_file" ]]; then
        echo "  ✓ 清理函数执行成功"
    else
        echo "  ✗ 清理函数执行失败"
        return 1
    fi

    echo "========================"
    echo "所有测试通过！"
    return 0
}

##
## 初始化错误处理框架
## 在脚本开始时调用
##
init_error_handler() {
    log_info "初始化错误处理框架..."

    # 重置全局状态
    ERROR_OCCURRED=false
    CLEANUP_FUNCS=()

    # 注册默认清理函数
    register_cleanup "execute_cleanup"

    log_info "错误处理框架初始化完成"
}
