#!/bin/bash

##
## 检查是否应该追加到 .add（同域名多协议共存）
## 返回 0 = 追加到 .add，返回 1 = 创建完整 .conf
##
caddy_should_append() {
    [[ ! -f ${is_caddy_site_file} ]] && return 1
    return 0
}

##
## 生成 Caddy reverse_proxy 块（用于追加到 .add 文件）
## 支持: ws, h2, grpc, xhttp
##
caddy_add_location() {
    local net_type="$1"
    local loc_path="$2"
    local loc_port="$3"
    local add_file="${is_caddy_site_file}.add"

    ##
    ## 检查路径是否已存在于 .conf 或 .add 中（字段级精确匹配，避免子串误判）
    ##
    local norm_path
    norm_path=$(echo "$loc_path" | sed 's|^/||;s|/\*$||;s|/$||')
    for f in "${is_caddy_site_file}" "${add_file}"; do
        if [[ -f "$f" ]] && [[ $(awk -v p="$norm_path" '
            /reverse_proxy/ {
                rp=$2; gsub(/\/\*$/, "", rp); gsub(/\/$/, "", rp); gsub(/^\//, "", rp)
                if (rp == p) { print "1"; exit }
            }' "$f" 2>/dev/null) == "1" ]]; then
            msg warn "路径 ${loc_path} 已存在于 Caddy 配置中，跳过追加"
            return 0
        fi
    done

    ##
    ## 追加 reverse_proxy 块到 .add 文件
    ## gRPC 路径确保有前导 /（去除重复后重新添加）
    ##
    local loc_block=""
    case $net_type in
    *grpc*)
        local grpc_path="${loc_path#/}"
        loc_block="reverse_proxy /${grpc_path}/* h2c://127.0.0.1:${loc_port}"
        ;;
    *h2*)
        loc_block="reverse_proxy ${loc_path} h2c://127.0.0.1:${loc_port}"
        ;;
    *ws* | *xhttp* | *http*)
        loc_block="reverse_proxy ${loc_path} 127.0.0.1:${loc_port}"
        ;;
    esac

    if [[ -n "$loc_block" ]]; then
        {
            echo "# Xray ${net_type}: ${host}${loc_path}"
            echo "$loc_block"
        } >>"$add_file"
        msg ok "已追加 reverse_proxy ${loc_path} 到 ${add_file}"
    fi
}

caddy_config() {
    is_caddy_site_file=$is_caddy_conf/${host}.conf
    case $1 in
    new)
        mkdir -p $is_caddy_dir $is_caddy_dir/sites $is_caddy_conf
        cat >$is_caddy_file <<-EOF
# don't edit this file #
# for more info, see https://wangyan-good.github.io/xray/caddy-auto-tls/
# 不要编辑这个文件 #
# 更多相关请阅读此文章: https://wangyan-good.github.io/xray/caddy-auto-tls/
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
        # 同域名多协议共存：追加到 .add 而不是覆盖 .conf
        if caddy_should_append; then
            msg warn "同域名已有 Caddy 配置，追加 reverse_proxy 到 .add 文件"
            caddy_add_location "ws" "${path}" "${port}"
            return 0
        fi
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    reverse_proxy ${path} 127.0.0.1:${port}
    import ${is_caddy_site_file}.add
}"
        ;;
    *h2*)
        # 同域名多协议共存：追加到 .add 而不是覆盖 .conf
        if caddy_should_append; then
            msg warn "同域名已有 Caddy 配置，追加 reverse_proxy 到 .add 文件"
            caddy_add_location "h2" "${path}" "${port}"
            return 0
        fi
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    reverse_proxy ${path} h2c://127.0.0.1:${port}
    import ${is_caddy_site_file}.add
}"
        ;;
    *grpc*)
        # 同域名多协议共存：追加到 .add 而不是覆盖 .conf
        if caddy_should_append; then
            msg warn "同域名已有 Caddy 配置，追加 reverse_proxy 到 .add 文件"
            caddy_add_location "grpc" "${path}" "${port}"
            return 0
        fi
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

    del)
        local add_file="${is_caddy_site_file}.add"
        local del_path="${path}"
        [[ -n "$is_del_json_path" ]] && del_path="$is_del_json_path"

        if [[ -f "$add_file" ]]; then
            local norm_path
            norm_path=$(echo "$del_path" | sed 's|^/||;s|/\*$||;s|/$||')
            awk -v p="$norm_path" '
                BEGIN { skip=0; prev_comment="" }
                /^[[:space:]]*#[[:space:]]*Xray/ {
                    prev_comment=$0
                    next
                }
                /^[[:space:]]*reverse_proxy/ {
                    rp=$2
                    gsub(/\/\*$/, "", rp)
                    gsub(/\/+$/, "", rp)
                    gsub(/^\/+/, "", rp)
                    if (rp == p) {
                        skip=1
                        prev_comment=""
                        next
                    }
                    if (prev_comment != "") print prev_comment
                    print
                    prev_comment=""
                    next
                }
                {
                    if (prev_comment != "") { print prev_comment; prev_comment="" }
                    if (!skip) print
                    skip=0
                }
            ' "$add_file" > "${add_file}.tmp"
            mv -f "${add_file}.tmp" "$add_file"
            msg ok "已从 ${add_file} 中删除 reverse_proxy ${del_path}"
        fi
        ;;
    esac
    [[ $1 != "new" && $1 != 'proxy' && $1 != 'del' ]] && {
        [[ ! -f ${is_caddy_site_file}.add ]] && echo "# see https://wangyan-good.github.io/xray/caddy-auto-tls/" >${is_caddy_site_file}.add
    }
}
