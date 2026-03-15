caddy_config() {
    is_caddy_site_file=$is_caddy_conf/${host}.conf
    case $1 in
    new)
        mkdir -p $is_caddy_dir $is_caddy_dir/sites $is_caddy_conf
        cat >$is_caddyfile <<-EOF
# don't edit this file #
# for more info, see https://wangyan-good.github.io/v2ray/caddy-auto-tls/
# 不要编辑这个文件 #
# 更多相关请阅读此文章: https://wangyan-good.github.io/v2ray/caddy-auto-tls/
# https://caddyserver.com/docs/caddyfile/options
{
  admin off
  http_port $is_http_port
  https_port $is_https_port
}
import $is_caddy_conf/*.conf
import $is_caddy_dir/sites/*.conf
EOF
        ;;
    *ws*)
        # 检测配置冲突
        [[ -f ${is_caddy_site_file} ]] && {
            msg warn "检测到已存在的 Caddy 配置：${is_caddy_site_file}"
            msg warn "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read caddy_conf_choice
                [[ ! $caddy_conf_choice ]] && caddy_conf_choice=1
                case $caddy_conf_choice in
                1)
                    cp -f ${is_caddy_site_file} ${is_caddy_site_file}.bak
                    msg ok "已备份现有配置：${is_caddy_site_file}.bak"
                    break
                    ;;
                2)
                    msg warn "跳过配置，保留现有配置"
                    return
                    ;;
                3)
                    msg warn "请手动编辑：${is_caddy_site_file}"
                    return
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    reverse_proxy ${path} 127.0.0.1:${port}
    import ${is_caddy_site_file}.add
}"
        ;;
    *h2*)
        # 检测配置冲突
        [[ -f ${is_caddy_site_file} ]] && {
            msg warn "检测到已存在的 Caddy 配置：${is_caddy_site_file}"
            msg warn "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read caddy_conf_choice
                [[ ! $caddy_conf_choice ]] && caddy_conf_choice=1
                case $caddy_conf_choice in
                1)
                    cp -f ${is_caddy_site_file} ${is_caddy_site_file}.bak
                    msg ok "已备份现有配置：${is_caddy_site_file}.bak"
                    break
                    ;;
                2)
                    msg warn "跳过配置，保留现有配置"
                    return
                    ;;
                3)
                    msg warn "请手动编辑：${is_caddy_site_file}"
                    return
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    reverse_proxy ${path} h2c://127.0.0.1:${port}
    import ${is_caddy_site_file}.add
}"
        ;;
    *grpc*)
        # 检测配置冲突
        [[ -f ${is_caddy_site_file} ]] && {
            msg warn "检测到已存在的 Caddy 配置：${is_caddy_site_file}"
            msg warn "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read caddy_conf_choice
                [[ ! $caddy_conf_choice ]] && caddy_conf_choice=1
                case $caddy_conf_choice in
                1)
                    cp -f ${is_caddy_site_file} ${is_caddy_site_file}.bak
                    msg ok "已备份现有配置：${is_caddy_site_file}.bak"
                    break
                    ;;
                2)
                    msg warn "跳过配置，保留现有配置"
                    return
                    ;;
                3)
                    msg warn "请手动编辑：${is_caddy_site_file}"
                    return
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    reverse_proxy /${path}/* h2c://127.0.0.1:${port}
    import ${is_caddy_site_file}.add
}"
        ;;
    proxy)
        
        cat >${is_caddy_site_file}.add <<<"
reverse_proxy https://$proxy_site {
        header_up Host {upstream_hostport}
}"
        ;;
    esac
    [[ $1 != "new" && $1 != 'proxy' ]] && {
        [[ ! -f ${is_caddy_site_file}.add ]] && echo "# see https://wangyan-good.github.io/v2ray/caddy-auto-tls/" >${is_caddy_site_file}.add
    }
}
