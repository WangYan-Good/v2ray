#!/bin/bash

##
## 将字符串转义为 JSON 安全格式（处理反斜杠、双引号、换行）
##
mihomo_json_str() {
    local s="${1:-}"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '"%s"\n' "$s"
}

##
## 生成或读取订阅 token（优先使用 openssl，否则使用 UUID）
##
mihomo_token() {
    [[ ! -d $is_sub_dir ]] && mkdir -p "$is_sub_dir"
    if [[ ! -s $is_sub_token_file ]]; then
        if [[ $(type -P openssl) ]]; then
            openssl rand -hex 16 >"$is_sub_token_file"
        else
            get_uuid
            echo "${tmp_uuid//-/}" >"$is_sub_token_file"
        fi
        chmod 600 "$is_sub_token_file" 2>/dev/null
    fi
    cat "$is_sub_token_file"
}

##
## 从配置文件目录中查找第一个可用的域名（Host）
## 用于 mihomo 订阅的默认域名
##
mihomo_first_host() {
    local file h
    [[ ! -d $is_conf_dir ]] && return
    for file in "$is_conf_dir"/*.json; do
        [[ ! -f "$file" || "$file" == *dynamic-port-*-link.json ]] && continue
        h=$(jq -r '.inbounds[0].streamSettings.wsSettings.headers.Host //
            .inbounds[0].streamSettings.grpc_host //
            .inbounds[0].streamSettings.httpSettings.host[0] //
            .inbounds[0].streamSettings.xhttpSettings.host //
            empty' "$file" 2>/dev/null | head -1)
        [[ -n $h ]] && echo "$h" && return
    done
}

##
## 根据网络类型（ws/grpc/xhttp）生成 mihomo 节点的网络配置选项
##
mihomo_node_opts() {
    local q_host q_path xhttp_mode
    q_host=$(mihomo_json_str "$host")
    q_path=$(mihomo_json_str "$path")

    case $net in
    ws)
        echo "    network: ws"
        echo "    ws-opts:"
        echo "      path: $q_path"
        [[ -n $host ]] && {
            echo "      headers:"
            echo "        Host: $q_host"
        }
        ;;
    grpc)
        echo "    network: grpc"
        echo "    grpc-opts:"
        echo "      grpc-service-name: $q_path"
        ;;
    xhttp)
        xhttp_mode=$(jq -r '.inbounds[0].streamSettings.xhttpSettings.mode // "auto"' <<<$is_json_str 2>/dev/null)
        [[ -z $xhttp_mode || $xhttp_mode == null ]] && xhttp_mode=auto
        echo "    network: xhttp"
        echo "    alpn:"
        echo "      - h2"
        echo "    xhttp-opts:"
        echo "      path: $q_path"
        [[ -n $host ]] && echo "      host: $q_host"
        echo "      mode: $(mihomo_json_str "$xhttp_mode")"
        ;;
    esac
}

##
## 根据协议类型（vmess/vless/trojan/shadowsocks）生成完整的 mihomo 节点配置
## 支持 TLS、Reality、xHTTP 等传输方式
##
mihomo_support_reason() {
    if [[ -n $is_dynamic_port ]]; then
        echo "dynamic-port is not supported by mihomo subscription"
        return
    fi

    case $is_protocol in
    vmess)
        case $net in
        tcp | "")
            [[ -n $header_type && $header_type != none ]] && echo "vmess tcp header type '$header_type' is not supported"
            ;;
        ws | grpc)
            ;;
        xhttp)
            echo "mihomo xhttp transport is VLESS only"
            ;;
        kcp | quic)
            echo "mihomo does not support $net transport"
            ;;
        *)
            echo "unsupported vmess transport: ${net:-tcp}"
            ;;
        esac
        ;;
    vless)
        case $net in
        tcp | ws | grpc | xhttp | reality | "")
            ;;
        kcp | quic)
            echo "mihomo does not support $net transport"
            ;;
        *)
            echo "unsupported vless transport: ${net:-tcp}"
            ;;
        esac
        ;;
    trojan)
        case $net in
        tcp | ws | grpc | "")
            ;;
        xhttp)
            echo "mihomo trojan transport supports ws/grpc/tcp only"
            ;;
        *)
            echo "unsupported trojan transport: ${net:-tcp}"
            ;;
        esac
        ;;
    shadowsocks | socks)
        ;;
    *)
        echo "unsupported protocol: $is_protocol"
        ;;
    esac
}

mihomo_is_supported() {
    [[ -z $(mihomo_support_reason) ]]
}

mihomo_node() {
    local name server node_port q_name q_server
    local q_uuid q_password q_method q_sni q_pbk q_user

    name="${is_config_name%.json}"
    server="${host:-$is_addr}"
    node_port="$port"
    [[ -n $host ]] && node_port="$is_https_port"
    q_name=$(mihomo_json_str "$name")
    q_server=$(mihomo_json_str "$server")
    q_uuid=$(mihomo_json_str "$uuid")
    q_password=$(mihomo_json_str "${trojan_password:-$ss_password}")
    q_method=$(mihomo_json_str "$ss_method")
    q_sni=$(mihomo_json_str "${is_servername:-$host}")
    q_pbk=$(mihomo_json_str "$is_public_key")
    q_user=$(mihomo_json_str "$is_socks_user")

    if ! mihomo_is_supported; then
        echo "  # skip $q_name: $(mihomo_support_reason)"
        return
    fi

    case $is_protocol in
    vmess)
        echo "  - name: $q_name"
        echo "    type: vmess"
        echo "    server: $q_server"
        echo "    port: $node_port"
        echo "    uuid: $q_uuid"
        echo "    alterId: 0"
        echo "    cipher: auto"
        echo "    udp: true"
        [[ $is_security == tls || -n $host ]] && {
            echo "    tls: true"
            [[ -n $host ]] && echo "    servername: $q_sni"
        }
        mihomo_node_opts
        ;;
    vless)
        echo "  - name: $q_name"
        echo "    type: vless"
        echo "    server: $q_server"
        echo "    port: $node_port"
        echo "    uuid: $q_uuid"
        echo "    udp: true"
        if [[ $net == reality ]]; then
            echo "    tls: true"
            echo "    flow: xtls-rprx-vision"
            echo "    servername: $q_sni"
            echo "    client-fingerprint: ios"
            echo "    reality-opts:"
            echo "      public-key: $q_pbk"
            echo "      short-id: \"\""
        elif [[ $is_security == tls || -n $host ]]; then
            echo "    tls: true"
            [[ -n $host ]] && echo "    servername: $q_sni"
        fi
        mihomo_node_opts
        ;;
    trojan)
        echo "  - name: $q_name"
        echo "    type: trojan"
        echo "    server: $q_server"
        echo "    port: $node_port"
        echo "    password: $q_password"
        echo "    udp: true"
        [[ $is_security == tls || -n $host ]] && {
            echo "    tls: true"
            [[ -n $host ]] && echo "    sni: $q_sni"
        }
        mihomo_node_opts
        ;;
    shadowsocks)
        echo "  - name: $q_name"
        echo "    type: ss"
        echo "    server: $q_server"
        echo "    port: $node_port"
        echo "    cipher: $q_method"
        echo "    password: $(mihomo_json_str "$ss_password")"
        echo "    udp: true"
        ;;
    socks)
        echo "  - name: $q_name"
        echo "    type: socks5"
        echo "    server: $q_server"
        echo "    port: $node_port"
        [[ -n $is_socks_user ]] && echo "    username: $q_user"
        [[ -n $is_socks_pass ]] && echo "    password: $(mihomo_json_str "$is_socks_pass")"
        echo "    udp: true"
        ;;
    *)
        echo "  # skip unsupported protocol: $q_name ($is_protocol)"
        ;;
    esac
}

##
## 生成完整的 mihomo 订阅配置文件（YAML 格式）
## 支持单个目标文件或扫描所有配置文件
##
mihomo_sub() {
    local target="${1:-}"
    local old_dont_show="$is_dont_show_info"
    local old_dont_exit="$is_dont_auto_exit"
    local files file path node_names=()

    echo "mixed-port: 7890"
    echo "allow-lan: false"
    echo "mode: rule"
    echo "log-level: info"
    echo "proxies:"

    is_dont_show_info=1
    is_dont_auto_exit=1
    if [[ -n $target ]]; then
        get file "$target"
        files=("$is_config_file")
    else
        files=()
        for path in "$is_conf_dir"/*.json; do
            [[ -e $path ]] || continue
            file=${path##*/}
            [[ $file == dynamic-port-*-link.json ]] && continue
            files+=("$file")
        done
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "  # no xray config found"
    fi

    for file in "${files[@]}"; do
        [[ -z $file ]] && continue
        unset is_config_file is_json_str is_protocol port uuid client_password trojan_password ss_method ss_password net is_security host path is_addr is_reality is_trojan is_servername is_public_key is_dynamic_port header_type is_socks_user is_socks_pass
        is_config_file="$file"
        info "$file" >/dev/null
        if mihomo_is_supported; then
            node_names+=("${is_config_name%.json}")
        fi
        mihomo_node
    done

    is_dont_show_info="$old_dont_show"
    is_dont_auto_exit="$old_dont_exit"

    echo "proxy-groups:"
    echo "  - name: PROXY"
    echo "    type: select"
    echo "    proxies:"
    for file in "${node_names[@]}"; do
        echo "      - $(mihomo_json_str "$file")"
    done
    echo "      - DIRECT"
    echo "rules:"
    echo "  - GEOIP,CN,DIRECT"
    echo "  - MATCH,PROXY"
}

##
## 为 Caddy 添加 mihomo 订阅路由配置
## 将订阅路径 /sub/mihomo 映射到订阅文件目录
##
mihomo_caddy_config() {
    local sub_host="$1"
    local token="$2"
    local add_file="$is_caddy_conf/${sub_host}.conf.add"
    [[ -z $sub_host || ! -f $is_caddy_conf/${sub_host}.conf ]] && return 1
    [[ ! -f $add_file ]] && echo "# mihomo subscription" >"$add_file"
    awk '
        /# xray-mihomo-sub-start/ { skip=1; next }
        /# xray-mihomo-sub-end/ { skip=0; next }
        !skip { print }
    ' "$add_file" >"${add_file}.tmp"
    mv -f "${add_file}.tmp" "$add_file"
    {
        echo "# xray-mihomo-sub-start"
        echo "@xray_mihomo_sub {"
        echo "    path /sub/mihomo"
        echo "    query token=$token"
        echo "}"
        echo "handle @xray_mihomo_sub {"
        echo "    root * $is_sub_dir"
        echo "    rewrite * /mihomo.yaml"
        echo "    header Content-Type text/yaml"
        echo "    file_server"
        echo "}"
        echo "# xray-mihomo-sub-end"
    } >>"$add_file"
    manage restart caddy &
}

##
## 为 Nginx 添加 mihomo 订阅路由配置
## 将订阅路径 /sub/mihomo 映射到订阅文件，并验证 token
##
mihomo_nginx_config() {
    local sub_host="$1"
    local token="$2"
    local add_file="$is_nginx_conf/${sub_host}.conf.add"
    [[ -z $sub_host || ! -f $is_nginx_conf/${sub_host}.conf ]] && return 1
    load nginx.sh
    [[ ! -f $add_file ]] && echo "# mihomo subscription" >"$add_file"
    awk '
        /# xray-mihomo-sub-start/ { skip=1; next }
        /# xray-mihomo-sub-end/ { skip=0; next }
        !skip { print }
    ' "$add_file" >"${add_file}.tmp"
    mv -f "${add_file}.tmp" "$add_file"
    {
        echo "    # xray-mihomo-sub-start"
        echo "    location = /sub/mihomo {"
        echo "        if (\$arg_token != \"$token\") {"
        echo "            return 403;"
        echo "        }"
        echo "        default_type text/yaml;"
        echo "        add_header Content-Disposition \"inline; filename=mihomo.yaml\";"
        echo "        alias $is_mihomo_sub_file;"
        echo "    }"
        echo "    # xray-mihomo-sub-end"
    } >>"$add_file"
    nginx_reload
}

##
## 刷新 mihomo 订阅文件并更新 Web 服务器配置
## 自动生成订阅文件并配置 Caddy/Nginx 路由
##
mihomo_refresh_sub() {
    local sub_host="${1:-$(mihomo_first_host)}"
    local token
    [[ ! -d $is_sub_dir ]] && mkdir -p "$is_sub_dir"
    mihomo_sub "" >"$is_mihomo_sub_file"
    chmod 644 "$is_mihomo_sub_file" 2>/dev/null
    token=$(mihomo_token)

    if [[ -n $sub_host ]]; then
        if [[ $is_caddy ]]; then
            mihomo_caddy_config "$sub_host" "$token" || true
        elif [[ $is_nginx ]]; then
            mihomo_nginx_config "$sub_host" "$token" || true
        fi
    fi

    msg "\nMihomo subscription refreshed: $is_mihomo_sub_file"
    mihomo_sub_url "$sub_host"
}

##
## 仅刷新 mihomo 订阅文件，不更新 Web 服务器配置
## 用于后台定时更新或手动触发文件生成
##
mihomo_refresh_file() {
    [[ ! -d $is_sub_dir ]] && mkdir -p "$is_sub_dir"
    mihomo_sub "" >"$is_mihomo_sub_file"
    chmod 644 "$is_mihomo_sub_file" 2>/dev/null
    mihomo_token >/dev/null
}

##
## 输出 mihomo 订阅 URL
## 包含域名、路径和 token 参数
##
mihomo_sub_url() {
    local sub_host="${1:-$(mihomo_first_host)}"
    local token
    token=$(mihomo_token)
    [[ -z $sub_host ]] && err "无法找到可用于订阅的域名，请使用: $is_core sub-url your-domain.com"
    msg "https://${sub_host}/sub/mihomo?token=${token}"
}
