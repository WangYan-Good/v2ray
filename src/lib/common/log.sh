#!/bin/bash
# log.sh - 统一日志系统

##
## 日志级别
##
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_NONE=4

# 默认日志级别
LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

##
## 统一日志格式函数
##
log() {
    local message="$*"
    echo "$message"
}

log_info() {
    log "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_warn() {
    log "[WARN] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_error() {
    log "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_debug() {
    [[ "$DEBUG" = "true" ]] && log "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

##
## 带颜色的日志函数（用于终端显示）
##
log_info_color() {
    echo -e "\e[92m[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*\e[0m"
}

log_warn_color() {
    echo -e "\e[93m[WARN] $(date '+%Y-%m-%d %H:%M:%S') $*\e[0m" >&2
}

log_error_color() {
    echo -e "\e[91m[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*\e[0m" >&2
}

log_debug_color() {
    [[ "$DEBUG" = "true" ]] && echo -e "\e[90m[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $*\e[0m" >&2
}

##
## 日志级别设置
##
IS_LOG_LEVEL_LIST=(
    debug
    info
    warning
    error
    none
    del
)

log_set() {
    if [[ $2 ]]; then
        for v in "${IS_LOG_LEVEL_LIST[@]}"; do
            [[ $(grep -E -i "^${2,,}$" <<<"$v") ]] && IS_LOG_LEVEL_USE=$v && break
        done
        [[ ! $IS_LOG_LEVEL_USE ]] && {
            err "无法识别 log 参数：$@ \n请使用 $IS_CORE log [${IS_LOG_LEVEL_LIST[@]}] 进行相关设定.\n备注：del 参数仅临时删除 log 文件; none 参数将不会生成 log 文件."
        }
        case $IS_LOG_LEVEL_USE in
        del)
            rm -rf "$IS_LOG_DIR"/*.log
            msg "\n $(_green 已临时删除 log 文件，如果你想要完全禁止生成 log 文件请使用：$IS_CORE log none)\n"
            ;;
        none)
            rm -rf "$IS_LOG_DIR"/*.log
            cat <<<$(jq '.log={"loglevel":"none"}' "$IS_CONFIG_JSON") >"$IS_CONFIG_JSON"
            ;;
        *)
            cat <<<$(jq '.log={access:"/var/log/'"$IS_CORE"'/access.log",error:"/var/log/'"$IS_CORE"'/error.log",loglevel:"'"$IS_LOG_LEVEL_USE"'"}' "$IS_CONFIG_JSON") >"$IS_CONFIG_JSON"
            ;;
        esac

        manage restart &
        [[ $2 != 'del' ]] && msg "\n已更新 Log 设定为：$(_green $IS_LOG_LEVEL_USE)\n"
    else
        case $1 in
        log)
            if [[ -f "$IS_LOG_DIR/access.log" ]]; then
                msg "\n 提醒：按 $(_green Ctrl + C) 退出\n"
                tail -f "$IS_LOG_DIR/access.log"
            else
                err "无法找到 log 文件."
            fi
            ;;
        *)
            if [[ -f "$IS_LOG_DIR/error.log" ]]; then
                msg "\n 提醒：按 $(_green Ctrl + C) 退出\n"
                tail -f "$IS_LOG_DIR/error.log"
            else
                err "无法找到 log 文件."
            fi
            ;;
        esac

    fi
}
