caddy_config() {
    IS_CADDY_SITE_FILE=$IS_CADDY_CONF/${HOST}.conf
    case $1 in
    new)
        mkdir -p $IS_CADDY_DIR $IS_CADDY_DIR/sites $IS_CADDY_CONF
        cat >$IS_CADDYFILE <<-EOF
# don't edit this file #
# for more info, see https://wangyan-good.github.io/v2ray/caddy-auto-tls/
# 不要编辑这个文件 #
# 更多相关请阅读此文章: https://wangyan-good.github.io/v2ray/caddy-auto-tls/
# https://caddyserver.com/docs/caddyfile/options
{
  admin off
  http_port $IS_HTTP_PORT
  https_port $IS_HTTPS_PORT
}
import $IS_CADDY_CONF/*.conf
import $IS_CADDY_DIR/sites/*.conf
EOF
        ;;
    *ws*)
        # 检测配置冲突
        [[ -f ${IS_CADDY_SITE_FILE} ]] && {
            msg WARNING "检测到已存在的 Caddy 配置：${IS_CADDY_SITE_FILE}"
            msg WARNING "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read CADDY_CONF_CHOICE
                [[ ! $CADDY_CONF_CHOICE ]] && CADDY_CONF_CHOICE=1
                case $CADDY_CONF_CHOICE in
                1)
                    cp -f ${IS_CADDY_SITE_FILE} ${IS_CADDY_SITE_FILE}.bak
                    msg OK "已备份现有配置：${IS_CADDY_SITE_FILE}.bak"
                    break
                    ;;
                2)
                    msg WARNING "跳过配置，保留现有配置"
                    return
                    ;;
                3)
                    msg WARNING "请手动编辑：${IS_CADDY_SITE_FILE}"
                    return
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        cat >${IS_CADDY_SITE_FILE} <<<"
${HOST}:${IS_HTTPS_PORT} {
    reverse_proxy ${URL_PATH} 127.0.0.1:${PORT}
    import ${IS_CADDY_SITE_FILE}.add
}"
        ;;
    *h2*)
        # 检测配置冲突
        [[ -f ${IS_CADDY_SITE_FILE} ]] && {
            msg WARNING "检测到已存在的 Caddy 配置：${IS_CADDY_SITE_FILE}"
            msg WARNING "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read CADDY_CONF_CHOICE
                [[ ! $CADDY_CONF_CHOICE ]] && CADDY_CONF_CHOICE=1
                case $CADDY_CONF_CHOICE in
                1)
                    cp -f ${IS_CADDY_SITE_FILE} ${IS_CADDY_SITE_FILE}.bak
                    msg OK "已备份现有配置：${IS_CADDY_SITE_FILE}.bak"
                    break
                    ;;
                2)
                    msg WARNING "跳过配置，保留现有配置"
                    return
                    ;;
                3)
                    msg WARNING "请手动编辑：${IS_CADDY_SITE_FILE}"
                    return
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        cat >${IS_CADDY_SITE_FILE} <<<"
${HOST}:${IS_HTTPS_PORT} {
    reverse_proxy ${URL_PATH} h2c://127.0.0.1:${PORT}
    import ${IS_CADDY_SITE_FILE}.add
}"
        ;;
    *grpc*)
        # 检测配置冲突
        [[ -f ${IS_CADDY_SITE_FILE} ]] && {
            msg WARNING "检测到已存在的 Caddy 配置：${IS_CADDY_SITE_FILE}"
            msg WARNING "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read CADDY_CONF_CHOICE
                [[ ! $CADDY_CONF_CHOICE ]] && CADDY_CONF_CHOICE=1
                case $CADDY_CONF_CHOICE in
                1)
                    cp -f ${IS_CADDY_SITE_FILE} ${IS_CADDY_SITE_FILE}.bak
                    msg OK "已备份现有配置：${IS_CADDY_SITE_FILE}.bak"
                    break
                    ;;
                2)
                    msg WARNING "跳过配置，保留现有配置"
                    return
                    ;;
                3)
                    msg WARNING "请手动编辑：${IS_CADDY_SITE_FILE}"
                    return
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        cat >${IS_CADDY_SITE_FILE} <<<"
${HOST}:${IS_HTTPS_PORT} {
    reverse_proxy /${URL_PATH}/* h2c://127.0.0.1:${PORT}
    import ${IS_CADDY_SITE_FILE}.add
}"
        ;;
    del)
        # 删除配置 - 遍历所有协议前缀的配置文件
        for conf in $IS_CADDY_CONF/${HOST}.conf $IS_CADDY_CONF/${HOST}.conf.add; do
            [[ -f $conf ]] && rm -f $conf
        done
        ;;
    proxy)
        
        cat >${IS_CADDY_SITE_FILE}.add <<<"
reverse_proxy https://$PROXY_SITE {
        header_up Host {upstream_hostport}
}"
        ;;
    esac
    [[ $1 != "new" && $1 != 'proxy' && $1 != 'del' ]] && {
        [[ ! -f ${IS_CADDY_SITE_FILE}.add ]] && echo "# see https://wangyan-good.github.io/v2ray/caddy-auto-tls/" >${IS_CADDY_SITE_FILE}.add
    }
    return 0
}
