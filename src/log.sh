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
        for v in ${IS_LOG_LEVEL_LIST[@]}; do
            [[ $(grep -E -i "^${2,,}$" <<<$v) ]] && IS_LOG_LEVEL_USE=$v && break
        done
        [[ ! $IS_LOG_LEVEL_USE ]] && {
            err "无法识别 log 参数: $@ \n请使用 $IS_CORE log [${IS_LOG_LEVEL_LIST[@]}] 进行相关设定.\n备注: del 参数仅临时删除 log 文件; none 参数将不会生成 log 文件."
        }
        case $IS_LOG_LEVEL_USE in
        del)
            rm -rf $IS_LOG_DIR/*.log
            msg "\n $(_green 已临时删除 log 文件, 如果你想要完全禁止生成 log 文件请使用: $IS_CORE log none)\n"
            ;;
        none)
            rm -rf $IS_LOG_DIR/*.log
            cat <<<$(jq '.log={"loglevel":"none"}' $IS_CONFIG_JSON) >$IS_CONFIG_JSON
            ;;
        *)
            cat <<<$(jq '.log={access:"/var/log/'$IS_CORE'/access.log",error:"/var/log/'$IS_CORE'/error.log",loglevel:"'$IS_LOG_LEVEL_USE'"}' $IS_CONFIG_JSON) >$IS_CONFIG_JSON
            ;;
        esac

        manage restart &
        [[ $2 != 'del' ]] && msg "\n已更新 Log 设定为: $(_green $IS_LOG_LEVEL_USE)\n"
    else
        case $1 in
        log)
            if [[ -f $IS_LOG_DIR/access.log ]]; then
                msg "\n 提醒: 按 $(_green Ctrl + C) 退出\n"
                tail -f $IS_LOG_DIR/access.log
            else
                err "无法找到 log 文件."
            fi
            ;;
        *)
            if [[ -f $IS_LOG_DIR/error.log ]]; then
                msg "\n 提醒: 按 $(_green Ctrl + C) 退出\n"
                tail -f $IS_LOG_DIR/error.log
            else
                err "无法找到 log 文件."
            fi
            ;;
        esac

    fi
}