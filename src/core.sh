#!/bin/bash
IS_CADDY_CONF=$IS_CADDY_DIR/$AUTHOR
IS_NGINX_CONF=$IS_NGINX_DIR/v2ray

PROTOCOL_LIST=(
    VMess-TCP
    VMess-mKCP
    VMess-QUIC
    VMess-H2-TLS
    VMess-WS-TLS
    VMess-gRPC-TLS
    VLESS-H2-TLS
    VLESS-WS-TLS
    VLESS-gRPC-TLS
    # VLESS-XTLS-uTLS-REALITY
    Trojan-H2-TLS
    Trojan-WS-TLS
    Trojan-gRPC-TLS
    Shadowsocks
    # Dokodemo-Door
    VMess-TCP-dynamic-port
    VMess-mKCP-dynamic-port
    VMess-QUIC-dynamic-port
    Socks
)
SS_METHOD_LIST=(
    aes-128-gcm
    aes-256-gcm
    chacha20-ietf-poly1305
    # xchacha20-ietf-poly1305
    # 2022-blake3-aes-128-gcm
    # 2022-blake3-aes-256-gcm
    # 2022-blake3-chacha20-poly1305
)
HEADER_TYPE_LIST=(
    none
    srtp
    utp
    wechat-video
    dtls
    wireguard
)
MAINMENU=(
    "添加配置"
    "更改配置"
    "查看配置"
    "删除配置"
    "运行管理"
    "更新"
    "卸载"
    "帮助"
    "其他"
    "关于"
)
INFO_LIST=(
    "协议 (protocol)"
    "地址 (address)"
    "端口 (port)"
    "用户ID (id)"
    "传输协议 (network)"
    "伪装类型 (type)"
    "伪装域名 (host)"
    "路径 (path)"
    "传输层安全 (TLS)"
    "mKCP seed"
    "密码 (password)"
    "加密方式 (encryption)"
    "链接 (URL)"
    "目标地址 (remote addr)"
    "目标端口 (remote port)"
    "流控 (flow)"
    "SNI (serverName)"
    "指纹 (Fingerprint)"
    "公钥 (Public key)"
    "用户名 (Username)"
)
CHANGE_LIST=(
    "更改协议"
    "更改端口"
    "更改域名"
    "更改路径"
    "更改密码"
    "更改 UUID"
    "更改加密方式"
    "更改伪装类型"
    "更改目标地址"
    "更改目标端口"
    "更改密钥"
    "更改 SNI (serverName)"
    "更改动态端口"
    "更改伪装网站"
    "更改 mKCP seed"
    "更改用户名 (Username)"
)
SERVERNAME_LIST=(
    www.amazon.com
    www.microsoft.com
    www.apple.com
    dash.cloudflare.com
    dl.google.com
    aws.amazon.com
)

IS_RANDOM_SS_METHOD=${SS_METHOD_LIST[$(shuf -i 0-${#SS_METHOD_LIST[@]} -n1) - 1]}
IS_RANDOM_HEADER_TYPE=${HEADER_TYPE_LIST[$(shuf -i 1-5 -n1)]} # random dont use none
IS_RANDOM_SERVERNAME=${SERVERNAME_LIST[$(shuf -i 0-${#SERVERNAME_LIST[@]} -n1) - 1]}

msg() {
    echo -e "$@"
}

msg_ul() {
    echo -e "\e[4m$@\e[0m"
}

# pause
pause() {
    echo
    echo -ne "按 $(_green Enter 回车键) 继续, 或按 $(_red Ctrl + C) 取消."
    read -rs -d $'\n'
    echo
}

get_uuid() {
    TMP_UUID=$(cat /proc/sys/kernel/random/uuid)
}

get_ip() {
    [[ $IP || $IS_NO_AUTO_TLS || $IS_GEN || $IS_DONT_GET_IP ]] && return

    ##
    ## 尝试多个 IP 获取服务
    ##
    local services=(
        "https://one.one.one.one/cdn-cgi/trace"
        "https://api.ip.sb/ip"
        "https://ifconfig.me/ip"
        "https://ipinfo.io/ip"
        "https://icanhazip.com"
    )

    for service in "${services[@]}"; do
        IP=$(_wget -4 -T 5 -qO- "$service" 2>/dev/null)
        # 清理可能的空白字符
        IP=$(echo "$IP" | tr -d '[:space:]')
        [[ $IP && $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
        IP=
    done

    ##
    ## 如果 IPv4 全部失败，尝试 IPv6
    ##
    [[ ! $IP ]] && {
        for service in "${services[@]}"; do
            IP=$(_wget -6 -T 5 -qO- "$service" 2>/dev/null)
            IP=$(echo "$IP" | tr -d '[:space:]')
            [[ $IP ]] && break
            IP=
        done
    }

    [[ ! $IP ]] && {
        err "获取服务器 IP 失败.."
    }
}

get_port() {
    IS_COUNT=0
    while :; do
        ((IS_COUNT++))
        if [[ $IS_COUNT -ge 233 ]]; then
            err "自动获取可用端口失败次数达到 233 次, 请检查端口占用情况."
        fi
        TMP_PORT=$(shuf -i 445-65535 -n 1)
        [[ ! $(is_test port_used $TMP_PORT) && $TMP_PORT != $PORT ]] && break
    done
}

get_pbk() {
    IS_TMP_PBK=($($IS_CORE_BIN x25519 | sed 's/.*://'))
    IS_PRIVATE_KEY=${IS_TMP_PBK[0]}
    IS_PUBLIC_KEY=${IS_TMP_PBK[1]}
}

show_list() {
    PS3=''
    COLUMNS=1
    select i in "$@"; do echo; done &
    wait
    # i=0
    # for v in "$@"; do
    #     ((i++))
    #     echo "$i) $V"
    # done
    # echo

}

is_test() {
    case $1 in
    number)
        echo $2 | grep -E '^[1-9][0-9]?+$'
        ;;
    port)
        if [[ $(is_test number $2) ]]; then
            [[ $2 -le 65535 ]] && echo ok
        fi
        ;;
    port_used)
        [[ $(is_port_used $2) && ! $IS_CANT_TEST_PORT ]] && echo ok
        ;;
    domain)
        echo $2 | grep -E -i '^\w(\w|\-|\.)?+\.\w+$'
        ;;
    path)
        echo $2 | grep -E -i '^\/\w(\w|\-|\/)?+\w$'
        ;;
    uuid)
        echo $2 | grep -E -i '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
        ;;
    esac

}

is_port_used() {
    if [[ $(type -P netstat) ]]; then
        [[ ! $IS_USED_PORT ]] && IS_USED_PORT="$(netstat -tunlp | sed -n 's/.*:\([0-9]\+\).*/\1/p' | sort -nu)"
        echo $IS_USED_PORT | sed 's/ /\n/g' | grep ^${1}$
        return
    fi
    if [[ $(type -P ss) ]]; then
        [[ ! $IS_USED_PORT ]] && IS_USED_PORT="$(ss -tunlp | sed -n 's/.*:\([0-9]\+\).*/\1/p' | sort -nu)"
        echo $IS_USED_PORT | sed 's/ /\n/g' | grep ^${1}$
        return
    fi
    IS_CANT_TEST_PORT=1
    msg "$IS_WARN 无法检测端口是否可用."
    msg "请执行: $(_yellow "${cmd} update -y; ${cmd} install net-tools -y") 来修复此问题."
}

##
## ask input a string or pick a option for list.
##
ask() {
    case $1 in
    set_ss_method)
        IS_TMP_LIST=(${SS_METHOD_LIST[@]})
        IS_DEFAULT_ARG=$IS_RANDOM_SS_METHOD
        IS_OPT_MSG="\n请选择加密方式:\n"
        IS_OPT_INPUT_MSG="(默认\e[92m $IS_DEFAULT_ARG\e[0m):"
        IS_ASK_SET=SS_METHOD
        ;;
    set_header_type)
        IS_TMP_LIST=(${HEADER_TYPE_LIST[@]})
        IS_DEFAULT_ARG=$IS_RANDOM_HEADER_TYPE
        [[ $(grep -i tcp <<<"$IS_NEW_PROTOCOL-$NET") ]] && {
            IS_TMP_LIST=(none http)
            IS_DEFAULT_ARG=none
        }
        IS_OPT_MSG="\n请选择伪装类型:\n"
        IS_OPT_INPUT_MSG="(默认\e[92m $IS_DEFAULT_ARG\e[0m):"
        IS_ASK_SET=header_type
        [[ $IS_USE_HEADER_TYPE ]] && return
        ;;
    set_protocol)
        IS_TMP_LIST=(${PROTOCOL_LIST[@]})
        [[ $IS_NO_AUTO_TLS ]] && {
            unset IS_TMP_LIST
            for v in ${PROTOCOL_LIST[@]}; do
                [[ $(grep -i tls$ <<<$v) ]] && IS_TMP_LIST=(${IS_TMP_LIST[@]} $v)
            done
        }
        IS_OPT_MSG="\n请选择协议:\n"
        IS_ASK_SET=IS_NEW_PROTOCOL
        ;;
    set_change_list)
        IS_TMP_LIST=()
        for v in ${IS_CAN_CHANGE[@]}; do
            IS_TMP_LIST+=("${CHANGE_LIST[$v]}")
        done
        IS_OPT_MSG="\n请选择更改:\n"
        IS_ASK_SET=IS_CHANGE_STR
        IS_OPT_INPUT_MSG=$3
        ;;
    string)
        IS_ASK_SET=$2
        IS_OPT_INPUT_MSG=$3
        ;;
    list)
        IS_ASK_SET=$2
        [[ ! $IS_TMP_LIST ]] && IS_TMP_LIST=($3)
        IS_OPT_MSG=$4
        IS_OPT_INPUT_MSG=$5
        ;;
    get_config_file)
        IS_TMP_LIST=("${IS_ALL_JSON[@]}")
        IS_OPT_MSG="\n请选择配置:\n"
        IS_ASK_SET=IS_CONFIG_FILE
        ;;
    mainmenu)
        IS_TMP_LIST=("${MAINMENU[@]}")
        IS_ASK_SET=IS_MAIN_PICK
        IS_EMPTY_EXIT=1
        ;;
    esac
    msg $IS_OPT_MSG
    [[ ! $IS_OPT_INPUT_MSG ]] && IS_OPT_INPUT_MSG="请选择 [\e[91m1-${#IS_TMP_LIST[@]}\e[0m]:"
    [[ $IS_TMP_LIST ]] && show_list "${IS_TMP_LIST[@]}"
    while :; do
        echo -ne $IS_OPT_INPUT_MSG
        read REPLY
        [[ ! $REPLY && $IS_EMPTY_EXIT ]] && exit
        [[ ! $REPLY && $IS_DEFAULT_ARG ]] && export $IS_ASK_SET=$IS_DEFAULT_ARG && break
        [[ "$REPLY" == "${IS_STR}2${IS_GET}3${IS_OPT}3" && $IS_ASK_SET == 'IS_MAIN_PICK' ]] && {
            msg "\n${IS_GET}2${IS_STR}3${IS_MSG}3b${IS_TMP}o${IS_OPT}y\n" && exit
        }
        if [[ ! $IS_TMP_LIST ]]; then
            [[ $(grep port <<<$IS_ASK_SET) ]] && {
                [[ ! $(is_test port "$REPLY") ]] && {
                    msg "$IS_ERR 请输入正确的端口, 可选(1-65535)"
                    continue
                }
                if [[ $(is_test port_used $REPLY) && $IS_ASK_SET != 'door_port' ]]; then
                    msg "$IS_ERR 无法使用 ($REPLY) 端口."
                    continue
                fi
            }
            [[ $(grep path <<<$IS_ASK_SET) && ! $(is_test path "$REPLY") ]] && {
                [[ ! $TMP_UUID ]] && get_uuid
                msg "$IS_ERR 请输入正确的路径, 例如: /$TMP_UUID"
                continue
            }
            [[ $(grep uuid <<<$IS_ASK_SET) && ! $(is_test uuid "$REPLY") ]] && {
                [[ ! $TMP_UUID ]] && get_uuid
                msg "$IS_ERR 请输入正确的 UUID, 例如: $TMP_UUID"
                continue
            }
            [[ $(grep ^y$ <<<$IS_ASK_SET) ]] && {
                [[ $(grep -i ^y$ <<<"$REPLY") ]] && break
                msg "请输入 (y)"
                continue
            }
            [[ $REPLY ]] && export $IS_ASK_SET=$REPLY && msg "使用: ${!IS_ASK_SET}" && break
        else
            [[ $(is_test number "$REPLY") ]] && IS_ASK_RESULT=${IS_TMP_LIST[$REPLY - 1]}
            [[ $IS_ASK_RESULT ]] && export $IS_ASK_SET="$IS_ASK_RESULT" && msg "选择: ${!IS_ASK_SET}" && break
        fi

        msg "输入${IS_ERR}"
    done
    unset IS_OPT_MSG IS_OPT_INPUT_MSG IS_TMP_LIST IS_ASK_RESULT IS_DEFAULT_ARG IS_EMPTY_EXIT
}

# create file
create() {
    case $1 in
    server)
        IS_TLS=none
        get new

        # file name
        if [[ $HOST ]]; then
            IS_CONFIG_NAME=$2-${HOST}.json
        else
            IS_CONFIG_NAME=$2-${PORT}.json
        fi
        IS_JSON_FILE=$IS_CONF_DIR/$IS_CONFIG_NAME
        # get json
        [[ $IS_CHANGE || ! $JSON_STR ]] && get protocol $2
        case $NET in
        ws | h2 | grpc | http)
            IS_LISTEN='"listen": "127.0.0.1"'
            ;;
        *)
            IS_LISTEN='"listen": "0.0.0.0"'
            ;;
        esac
        IS_SNIFFING='sniffing:{enabled:true,destOverride:["http","tls"]}'
        IS_NEW_JSON=$(jq '{inbounds:[{tag:'\"$IS_CONFIG_NAME\"',port:'"$PORT"','"$IS_LISTEN"',protocol:'\"$IS_PROTOCOL\"','"$JSON_STR"','"$IS_SNIFFING"'}]}' <<<{})
        if [[ $IS_DYNAMIC_PORT ]]; then
            [[ ! $IS_DYNAMIC_PORT_RANGE ]] && get dynamic-port
            IS_NEW_DYNAMIC_PORT_JSON=$(jq '{inbounds:[{tag:'\"$IS_CONFIG_NAME-link.json\"',port:'\"$IS_DYNAMIC_PORT_RANGE\"','"$IS_LISTEN"',protocol:"vmess",'"$IS_STREAM"','"$IS_SNIFFING"',allocate:{strategy:"random"}}]}' <<<{})
        fi
        [[ $IS_TEST_JSON ]] && return # tmp test
        # only show json, dont save to file.
        [[ $IS_GEN ]] && {
            msg
            jq <<<$IS_NEW_JSON
            msg
            [[ $IS_NEW_DYNAMIC_PORT_JSON ]] && jq <<<$IS_NEW_DYNAMIC_PORT_JSON && msg
            return
        }
        # del old file
        [[ $IS_CONFIG_FILE ]] && IS_NO_DEL_MSG=1 && del $IS_CONFIG_FILE
        # save json to file
        cat <<<$IS_NEW_JSON >$IS_JSON_FILE
        [[ $IS_NEW_DYNAMIC_PORT_JSON ]] && {
            IS_DYNAMIC_PORT_LINK_FILE=$IS_JSON_FILE-link.json
            cat <<<$IS_NEW_DYNAMIC_PORT_JSON >$IS_DYNAMIC_PORT_LINK_FILE
        }
        if [[ $IS_NEW_INSTALL ]]; then
            # config.json
            create config.json
        else
            # use api add config
            api add $IS_JSON_FILE $IS_DYNAMIC_PORT_LINK_FILE &>/dev/null
        fi
        # auto tls (caddy or nginx)
        # 只有 TLS 协议（WS/H2/gRPC）需要配置反向代理
        [[ $HOST && ! $IS_NO_AUTO_TLS && $IS_USE_TLS ]] && {
            if [[ $IS_CADDY ]]; then
                create caddy $NET
            elif [[ $IS_NGINX ]]; then
                create nginx $IS_NEW_PROTOCOL "" "$URL_PATH" "$PORT"
            fi
        }
        # restart core
        [[ $IS_API_FAIL ]] && manage restart &
        ;;
    client)
        IS_TLS=tls
        IS_CLIENT=1
        get info $2
        [[ ! $IS_CLIENT_ID_JSON ]] && err "($IS_CONFIG_NAME) 不支持生成客户端配置."
        IS_NEW_JSON=$(jq '{outbounds:[{tag:'\"$IS_CONFIG_NAME\"',protocol:'\"$IS_PROTOCOL\"','"$IS_CLIENT_ID_JSON"','"$IS_STREAM"'}]}' <<<{})
        if [[ $IS_FULL_CLIENT ]]; then
            IS_DNS='dns:{servers:[{address:"223.5.5.5",domain:["geosite:cn","geosite:geolocation-cn"],expectIPs:["geoip:cn"]},"1.1.1.1","8.8.8.8"]}'
            IS_ROUTE='routing:{rules:[{type:"field",outboundTag:"direct",ip:["geoip:cn","geoip:private"]},{type:"field",outboundTag:"direct",domain:["geosite:cn","geosite:geolocation-cn"]}]}'
            IS_INBOUNDS='inbounds:[{port:2333,listen:"127.0.0.1",protocol:"socks",settings:{udp:true},sniffing:{enabled:true,destOverride:["http","tls"]}}]'
            IS_OUTBOUNDS='outbounds:[{tag:'\"$IS_CONFIG_NAME\"',protocol:'\"$IS_PROTOCOL\"','"$IS_CLIENT_ID_JSON"','"$IS_STREAM"'},{tag:"direct",protocol:"freedom"}]'
            IS_NEW_JSON=$(jq '{'$IS_DNS,$IS_ROUTE,$IS_INBOUNDS,$IS_OUTBOUNDS'}' <<<{})
        fi
        msg
        jq <<<$IS_NEW_JSON
        msg
        ;;
    caddy)
        load caddy.sh
        [[ $IS_INSTALL_CADDY ]] && caddy_config new
        [[ ! $(grep "$IS_CADDY_CONF" $IS_CADDYFILE) ]] && {
            msg "import $IS_CADDY_CONF/*.conf" >>$IS_CADDYFILE
        }
        [[ ! -d $IS_CADDY_CONF ]] && mkdir -p $IS_CADDY_CONF
        caddy_config $2
        manage restart caddy &
        ;;
    nginx)
        load nginx.sh
        [[ $IS_INSTALL_NGINX ]] && nginx_config new "" "$URL_PATH" "$PORT"
        [[ ! -d $IS_NGINX_CONF ]] && mkdir -p $IS_NGINX_CONF
        if ! nginx_config $2 "" "$URL_PATH" "$PORT"; then
            msg ERROR "Nginx 配置生成失败，证书申请未成功"
            msg WARNING "V2Ray 配置已生成，但 TLS 尚未启用"
            msg WARNING "你可以稍后手动申请证书并重载 Nginx"
            IS_API_FAIL=1
        fi
        nginx_reload
        ;;
    config.json)
        get_port
        IS_LOG='log:{access:"/var/log/'"$IS_CORE"'/access.log",error:"/var/log/'"$IS_CORE"'/error.log",loglevel:"warning"}'
        IS_DNS='dns:{}'
        IS_API='api:{tag:"api",services:["HandlerService","LoggerService","StatsService"]}'
        IS_STATS='stats:{}'
        IS_POLICY_SYSTEM='system:{statsInboundUplink:true,statsInboundDownlink:true,statsOutboundUplink:true,statsOutboundDownlink:true}'
        IS_POLICY='policy:{levels:{"0":{handshake:'"$((${TMP_PORT:0:1} + 1))"',connIdle:'"${TMP_PORT:0:3}"',uplinkOnly:'"$((${TMP_PORT:2:1} + 1))"',downlinkOnly:'"$((${TMP_PORT:3:1} + 3))"',statsUserUplink:true,statsUserDownlink:true}},'"$IS_POLICY_SYSTEM"'}'
        IS_BAN_AD='{type:"field",domain:["geosite:category-ads-all"],marktag:"ban_ad",outboundTag:"block"}'
        IS_BAN_BT='{type:"field",protocol:["bittorrent"],marktag:"ban_bt",outboundTag:"block"}'
        IS_BAN_CN='{type:"field",ip:["geoip:cn"],marktag:"ban_geoip_cn",outboundTag:"block"}'
        IS_OPENAI='{type:"field",domain:["domain:openai.com"],marktag:"fix_openai",outboundTag:"direct"}'
        IS_ROUTING='routing:{domainStrategy:"IPIfNonMatch",rules:[{type:"field",inboundTag:["api"],outboundTag:"api"},'"$IS_BAN_BT"','"$IS_BAN_CN"','"$IS_OPENAI"',{type:"field",ip:["geoip:private"],outboundTag:"block"}]}'
        IS_INBOUNDS='inbounds:[{tag:"api",port:'"$TMP_PORT"',listen:"127.0.0.1",protocol:"dokodemo-door",settings:{address:"127.0.0.1"}}]'
        IS_OUTBOUNDS='outbounds:[{tag:"direct",protocol:"freedom"},{tag:"block",protocol:"blackhole"}]'
        IS_SERVER_CONFIG_JSON=$(jq '{'"$IS_LOG"','"$IS_DNS"','"$IS_API"','"$IS_STATS"','"$IS_POLICY"','"$IS_ROUTING"','"$IS_INBOUNDS"','"$IS_OUTBOUNDS"'}' <<<{})
        cat <<<$IS_SERVER_CONFIG_JSON >$IS_CONFIG_JSON
        manage restart &
        ;;
    esac
}

# change config file
change() {
    IS_CHANGE=1
    IS_DONT_SHOW_INFO=1
    if [[ $2 ]]; then
        case ${2,,} in
        full)
            IS_CHANGE_ID=full
            ;;
        new)
            IS_CHANGE_ID=0
            ;;
        port)
            IS_CHANGE_ID=1
            ;;
        host)
            IS_CHANGE_ID=2
            ;;
        path)
            IS_CHANGE_ID=3
            ;;
        pass | passwd | password)
            IS_CHANGE_ID=4
            ;;
        id | uuid)
            IS_CHANGE_ID=5
            ;;
        ssm | method | ss-method | ss_method)
            IS_CHANGE_ID=6
            ;;
        type | header | header-type | header_type)
            IS_CHANGE_ID=7
            ;;
        dda | door-addr | door_addr)
            IS_CHANGE_ID=8
            ;;
        ddp | door-port | door_port)
            IS_CHANGE_ID=9
            ;;
        key | publickey | privatekey)
            IS_CHANGE_ID=10
            ;;
        sni | servername | servernames)
            IS_CHANGE_ID=11
            ;;
        dp | dyp | dynamic | dynamicport | dynamic-port)
            IS_CHANGE_ID=12
            ;;
        web | proxy-site)
            IS_CHANGE_ID=13
            ;;
        seed | kcpseed | kcp-seed | kcp_seed)
            IS_CHANGE_ID=14
            ;;
        *)
            [[ $IS_TRY_CHANGE ]] && return
            err "无法识别 ($2) 更改类型."
            ;;
        esac
    fi
    [[ $IS_TRY_CHANGE ]] && return
    [[ $IS_DONT_AUTO_EXIT ]] && {
        get info $1
    } || {
        [[ $IS_CHANGE_ID ]] && {
            IS_CHANGE_MSG=${CHANGE_LIST[$IS_CHANGE_ID]}
            [[ $IS_CHANGE_ID == 'full' ]] && {
                [[ $3 ]] && IS_CHANGE_MSG="更改多个参数" || IS_CHANGE_MSG=
            }
            [[ $IS_CHANGE_MSG ]] && _green "\n快速执行: $IS_CHANGE_MSG"
        }
        info $1
        [[ $IS_AUTO_GET_CONFIG ]] && msg "\n自动选择: $IS_CONFIG_FILE"
    }
    IS_OLD_NET=$NET
    [[ $IS_PROTOCOL == 'vless' && ! $IS_REALITY ]] && NET=v$NET
    [[ $IS_PROTOCOL == 'trojan' ]] && NET=t$NET
    [[ $IS_DYNAMIC_PORT ]] && NET=${NET}d
    [[ $3 == 'auto' ]] && IS_AUTO=1
    # if IS_DONT_SHOW_INFO exist, cant show info.
    IS_DONT_SHOW_INFO=
    # if not prefer args, show change list and then get change id.
    [[ ! $IS_CHANGE_ID ]] && {
        ask set_change_list
        IS_CHANGE_ID=${IS_CAN_CHANGE[$REPLY - 1]}
    }
    case $IS_CHANGE_ID in
    full)
        add $NET ${@:3}
        ;;
    0)
        # new protocol
        IS_SET_NEW_PROTOCOL=1
        add ${@:3}
        ;;
    1)
        # new port
        IS_NEW_PORT=$3
        [[ $HOST && ! $IS_CADDY && ! $IS_NGINX || $IS_NO_AUTO_TLS ]] && err "($IS_CONFIG_FILE) 不支持更改端口, 因为没啥意义."
        if [[ $IS_NEW_PORT && ! $IS_AUTO ]]; then
            [[ ! $(is_test port $IS_NEW_PORT) ]] && err "请输入正确的端口, 可选(1-65535)"
            [[ $IS_NEW_PORT != 443 && $(is_test port_used $IS_NEW_PORT) ]] && err "无法使用 ($IS_NEW_PORT) 端口"
        fi
        [[ $IS_AUTO ]] && get_port && IS_NEW_PORT=$TMP_PORT
        [[ ! $IS_NEW_PORT ]] && ask string IS_NEW_PORT "请输入新端口:"
        if [[ $HOST && ($IS_CADDY || $IS_NGINX) ]]; then
            NET=$IS_OLD_NET
            IS_HTTPS_PORT=$IS_NEW_PORT
            if [[ $IS_CADDY ]]; then
                load caddy.sh
                caddy_config $NET
                manage restart caddy &
            elif [[ $IS_NGINX ]]; then
                load nginx.sh
                nginx_config $NET "" "$URL_PATH" "$PORT"
                nginx_reload
            fi
            info
        else
            add $NET $IS_NEW_PORT
        fi
        ;;
    2)
        # new host
        IS_NEW_HOST=$3
        [[ ! $HOST ]] && err "($IS_CONFIG_FILE) 不支持更改域名."
        [[ ! $IS_NEW_HOST ]] && ask string IS_NEW_HOST "请输入新域名:"
        OLD_HOST=$HOST # del old host
        add $NET $IS_NEW_HOST
        ;;
    3)
        # new path
        IS_NEW_PATH=$3
        [[ ! $URL_PATH ]] && err "($IS_CONFIG_FILE) 不支持更改路径."
        [[ $IS_AUTO ]] && get_uuid && IS_NEW_PATH=/$TMP_UUID
        [[ ! $IS_NEW_PATH ]] && ask string IS_NEW_PATH "请输入新路径:"
        add $NET auto auto $IS_NEW_PATH
        ;;
    4)
        # new password
        IS_NEW_PASS=$3
        if [[ $NET == 'ss' || $IS_TROJAN || $IS_SOCKS_PASS ]]; then
            [[ $IS_AUTO ]] && get_uuid && IS_NEW_PASS=$TMP_UUID
        else
            err "($IS_CONFIG_FILE) 不支持更改密码."
        fi
        [[ ! $IS_NEW_PASS ]] && ask string IS_NEW_PASS "请输入新密码:"
        TROJAN_PASSWORD=$IS_NEW_PASS
        SS_PASSWORD=$IS_NEW_PASS
        IS_SOCKS_PASS=$IS_NEW_PASS
        add $NET
        ;;
    5)
        # new uuid
        IS_NEW_UUID=$3
        [[ ! $UUID ]] && err "($IS_CONFIG_FILE) 不支持更改 UUID."
        [[ $IS_AUTO ]] && get_uuid && IS_NEW_UUID=$TMP_UUID
        [[ ! $IS_NEW_UUID ]] && ask string IS_NEW_UUID "请输入新 UUID:"
        add $NET auto $IS_NEW_UUID
        ;;
    6)
        # new method
        IS_NEW_METHOD=$3
        [[ $NET != 'ss' ]] && err "($IS_CONFIG_FILE) 不支持更改加密方式."
        [[ $IS_AUTO ]] && IS_NEW_METHOD=$IS_RANDOM_SS_METHOD
        [[ ! $IS_NEW_METHOD ]] && {
            ask set_ss_method
            IS_NEW_METHOD=$SS_METHOD
        }
        add $NET auto auto $IS_NEW_METHOD
        ;;
    7)
        # new header type
        IS_NEW_HEADER_TYPE=$3
        [[ ! $HEADER_TYPE ]] && err "($IS_CONFIG_FILE) 不支持更改伪装类型."
        [[ $IS_AUTO ]] && {
            IS_NEW_HEADER_TYPE=$IS_RANDOM_HEADER_TYPE
            if [[ $NET == 'tcp' ]]; then
                IS_TMP_HEADER_TYPE=(none http)
                IS_NEW_HEADER_TYPE=${IS_TMP_HEADER_TYPE[$(shuf -i 0-1 -n1)]}
            fi
        }
        [[ ! $IS_NEW_HEADER_TYPE ]] && {
            ask set_header_type
            IS_NEW_HEADER_TYPE=$HEADER_TYPE
        }
        add $NET auto auto $IS_NEW_HEADER_TYPE
        ;;
    8)
        # new remote addr
        IS_NEW_DOOR_ADDR=$3
        [[ $NET != 'door' ]] && err "($IS_CONFIG_FILE) 不支持更改目标地址."
        [[ ! $IS_NEW_DOOR_ADDR ]] && ask string IS_NEW_DOOR_ADDR "请输入新的目标地址:"
        DOOR_ADDR=$IS_NEW_DOOR_ADDR
        add $NET
        ;;
    9)
        # new remote port
        IS_NEW_DOOR_PORT=$3
        [[ $NET != 'door' ]] && err "($IS_CONFIG_FILE) 不支持更改目标端口."
        [[ ! $IS_NEW_DOOR_PORT ]] && {
            ask string door_port "请输入新的目标端口:"
            IS_NEW_DOOR_PORT=$DOOR_PORT
        }
        add $NET auto auto $IS_NEW_DOOR_PORT
        ;;
    10)
        # new is_private_key is_public_key
        IS_NEW_PRIVATE_KEY=$3
        IS_NEW_PUBLIC_KEY=$4
        [[ ! $IS_REALITY ]] && err "($IS_CONFIG_FILE) 不支持更改密钥."
        if [[ $IS_AUTO ]]; then
            get_pbk
            add $NET
        else
            [[ $IS_NEW_PRIVATE_KEY && ! $IS_NEW_PUBLIC_KEY ]] && {
                err "无法找到 Public key."
            }
            [[ ! $IS_NEW_PRIVATE_KEY ]] && ask string IS_NEW_PRIVATE_KEY "请输入新 Private key:"
            [[ ! $IS_NEW_PUBLIC_KEY ]] && ask string IS_NEW_PUBLIC_KEY "请输入新 Public key:"
            if [[ $IS_NEW_PRIVATE_KEY == $IS_NEW_PUBLIC_KEY ]]; then
                err "Private key 和 Public key 不能一样."
            fi
            IS_PRIVATE_KEY=$IS_NEW_PRIVATE_KEY
            IS_TEST_JSON=1
            # create server $IS_PROTOCOL-$NET | $IS_CORE_BIN -test &>/dev/null
            create server $IS_PROTOCOL-$NET
            $IS_CORE_BIN -test <<<"$IS_NEW_JSON" &>/dev/null
            if [[ $? != 0 ]]; then
                err "Private key 无法通过测试."
            fi
            IS_PRIVATE_KEY=$IS_NEW_PUBLIC_KEY
            # create server $IS_PROTOCOL-$NET | $IS_CORE_BIN -test &>/dev/null
            create server $IS_PROTOCOL-$NET
            $IS_CORE_BIN -test <<<"$IS_NEW_JSON" &>/dev/null
            if [[ $? != 0 ]]; then
                err "Public key 无法通过测试."
            fi
            IS_PRIVATE_KEY=$IS_NEW_PRIVATE_KEY
            IS_PUBLIC_KEY=$IS_NEW_PUBLIC_KEY
            IS_TEST_JSON=
            add $NET
        fi
        ;;
    11)
        # new serverName
        IS_NEW_SERVERNAME=$3
        [[ ! $IS_REALITY ]] && err "($IS_CONFIG_FILE) 不支持更改 serverName."
        [[ $IS_AUTO ]] && IS_NEW_SERVERNAME=$IS_RANDOM_SERVERNAME
        [[ ! $IS_NEW_SERVERNAME ]] && ask string IS_NEW_SERVERNAME "请输入新的 serverName:"
        IS_SERVERNAME=$IS_NEW_SERVERNAME
        add $NET
        ;;
    12)
        # new dynamic-port
        IS_NEW_DYNAMIC_PORT_START=$3
        IS_NEW_DYNAMIC_PORT_END=$4
        [[ ! $IS_DYNAMIC_PORT ]] && err "($IS_CONFIG_FILE) 不支持更改动态端口."
        if [[ $IS_AUTO ]]; then
            get dynamic-port
            add $NET
        else
            [[ $IS_NEW_DYNAMIC_PORT_START && ! $IS_NEW_DYNAMIC_PORT_END ]] && {
                err "无法找到动态结束端口."
            }
            [[ ! $IS_NEW_DYNAMIC_PORT_START ]] && ask string IS_NEW_DYNAMIC_PORT_START "请输入新的动态开始端口:"
            [[ ! $IS_NEW_DYNAMIC_PORT_END ]] && ask string IS_NEW_DYNAMIC_PORT_END "请输入新的动态结束端口:"
            add $NET auto auto auto $IS_NEW_DYNAMIC_PORT_START $IS_NEW_DYNAMIC_PORT_END
        fi
        ;;
    13)
        # new proxy site
        IS_NEW_PROXY_SITE=$3
        [[ ! $IS_CADDY && ! $IS_NGINX && ! $HOST ]] && {
            err "($IS_CONFIG_FILE) 不支持更改伪装网站."
        }
        [[ $IS_CADDY && ! -f $IS_CADDY_CONF/${HOST}.conf.add ]] || [[ $IS_NGINX && ! -f $IS_NGINX_CONF/${HOST}.conf.add ]] && err "无法配置伪装网站."
        [[ ! $IS_NEW_PROXY_SITE ]] && ask string IS_NEW_PROXY_SITE "请输入新的伪装网站 (例如 example.com):"
        PROXY_SITE=$(sed 's#^.*//##;s#/$##' <<<$IS_NEW_PROXY_SITE)
        load caddy.sh
        caddy_config proxy
        manage restart caddy &
        msg "\n已更新伪装网站为: $(_green $PROXY_SITE) \n"
        ;;
    14)
        # new kcp seed
        IS_NEW_KCP_SEED=$3
        [[ ! $KCP_SEED ]] && err "($IS_CONFIG_FILE) 不支持更改 mKCP seed."
        [[ $IS_AUTO ]] && get_uuid && IS_NEW_KCP_SEED=$TMP_UUID
        [[ ! $IS_NEW_KCP_SEED ]] && ask string IS_NEW_KCP_SEED "请输入新 mKCP seed:"
        KCP_SEED=$IS_NEW_KCP_SEED
        add $NET
        ;;
    15)
        # new socks user
        [[ ! $IS_SOCKS_USER ]] && err "($IS_CONFIG_FILE) 不支持更改用户名 (Username)."
        ask string IS_SOCKS_USER "请输入新用户名 (Username):"
        add $NET
        ;;
    esac
}

# delete config.
del() {
    # dont get ip
    IS_DONT_GET_IP=1
    [[ $IS_CONF_DIR_EMPTY ]] && return # not found any json file.
    # get a config file
    [[ ! $IS_CONFIG_FILE ]] && get info $1
    if [[ $IS_CONFIG_FILE ]]; then
        if [[ $IS_MAIN_START && ! $IS_NO_DEL_MSG ]]; then
            msg "\n是否删除配置文件?: $IS_CONFIG_FILE"
            pause
        fi
        api del $IS_CONF_DIR/"$IS_CONFIG_FILE" $IS_DYNAMIC_PORT_FILE &>/dev/null
        rm -rf $IS_CONF_DIR/"$IS_CONFIG_FILE" $IS_DYNAMIC_PORT_FILE
        [[ $IS_API_FAIL && ! $IS_NEW_JSON ]] && manage restart &
        [[ ! $IS_NO_DEL_MSG ]] && _green "\n已删除: $IS_CONFIG_FILE\n"

        [[ $IS_CADDY ]] && {
            IS_DEL_HOST=$HOST
            [[ $IS_CHANGE ]] && {
                [[ ! $OLD_HOST ]] && return # no host exist or not set new host;
                IS_DEL_HOST=$OLD_HOST
            }
            [[ $IS_DEL_HOST && $HOST != $OLD_HOST && ! $IS_NO_AUTO_TLS ]] && {
                rm -rf $IS_CADDY_CONF/$IS_DEL_HOST.conf $IS_CADDY_CONF/$IS_DEL_HOST.conf.add
                [[ ! $IS_NEW_JSON ]] && manage restart caddy &
            }
        }
        [[ $IS_NGINX ]] && {
            load nginx.sh
            nginx_config del
            nginx_reload
        }
    fi
    if [[ ! $(ls $IS_CONF_DIR | grep .json) && ! $IS_CHANGE ]]; then
        warn "当前配置目录为空! 因为你刚刚删除了最后一个配置文件."
        IS_CONF_DIR_EMPTY=1
    fi
    unset IS_DONT_GET_IP
    [[ $IS_DONT_AUTO_EXIT ]] && unset IS_CONFIG_FILE
}

# uninstall
uninstall() {
    [[ $1 == "--quiet" ]] && IS_QUIET=1

    if [[ $IS_QUIET ]]; then
        # 静默卸载，默认只卸载 V2Ray
        IS_DO_UNINSTALL=1
    elif [[ $IS_CADDY ]]; then
        IS_TMP_LIST=("卸载 $IS_CORE_NAME" "卸载 ${IS_CORE_NAME} & Caddy")
        ask list IS_DO_UNINSTALL
    else
        ask string y "是否卸载 ${IS_CORE_NAME}? [y]:"
    fi
    manage stop &>/dev/null
    manage disable &>/dev/null
    rm -rf $IS_CORE_DIR $IS_LOG_DIR $IS_SH_BIN /lib/systemd/system/$IS_CORE.service
    sed -i "/$IS_CORE/d" /root/.bashrc
    # uninstall caddy; 2 is ask result
    if [[ $IS_DO_UNINSTALL == '2' ]]; then
        manage stop caddy &>/dev/null
        manage disable caddy &>/dev/null
        rm -rf $IS_CADDY_DIR $IS_CADDY_BIN /lib/systemd/system/caddy.service
    fi
    [[ $IS_INSTALL_SH ]] && return # reinstall
    _green "\n卸载完成!"
    msg "脚本哪里需要完善? 请反馈"
    msg "反馈问题) $(msg_ul https://github.com/${IS_SH_REPO}/issues)\n"
}

# manage run status
manage() {
    [[ $IS_DONT_AUTO_EXIT ]] && return
    case $1 in
    1 | start)
        IS_DO=start
        IS_DO_MSG=启动
        IS_TEST_RUN=1
        ;;
    2 | stop)
        IS_DO=stop
        IS_DO_MSG=停止
        ;;
    3 | r | restart)
        IS_DO=restart
        IS_DO_MSG=重启
        IS_TEST_RUN=1
        ;;
    *)
        IS_DO=$1
        IS_DO_MSG=$1
        ;;
    esac
    case $2 in
    caddy)
        IS_DO_NAME=$2
        IS_RUN_BIN=$IS_CADDY_BIN
        IS_DO_NAME_MSG=Caddy
        ;;
    *)
        IS_DO_NAME=$IS_CORE
        IS_RUN_BIN=$IS_CORE_BIN
        IS_DO_NAME_MSG=$IS_CORE_NAME
        ;;
    esac
    systemctl $IS_DO $IS_DO_NAME
    [[ $IS_TEST_RUN && ! $IS_NEW_INSTALL ]] && {
        sleep 2
        if [[ ! $(pgrep -f $IS_RUN_BIN) ]]; then
            IS_RUN_FAIL=${IS_DO_NAME_MSG,,}
            [[ ! $IS_NO_MANAGE_MSG ]] && {
                msg
                warn "($IS_DO_MSG) $IS_DO_NAME_MSG 失败"
                _yellow "检测到运行失败, 自动执行测试运行."
                get test-run
                _yellow "测试结束, 请按 Enter 退出."
            }
        fi
    }
}

# use api add or del inbounds
api() {
    [[ $IS_CORE_VER_LT_5 ]] && {
        warn "$IS_CORE_VER 版本不支持使用 API 操作. 请升级内核版本: $IS_CORE UPDATE CORE"
        IS_API_FAIL=1
        return
    }
    [[ ! $1 ]] && err "无法识别 API 的参数."
    [[ $IS_CORE_STOP ]] && {
        warn "$IS_CORE_NAME 当前处于停止状态."
        IS_API_FAIL=1
        return
    }
    case $1 in
    add)
        IS_API_DO=adi
        ;;
    del)
        IS_API_DO=rmi
        ;;
    s)
        IS_API_DO=stats
        ;;
    t | sq)
        IS_API_DO=statsquery
        ;;
    esac
    [[ ! $IS_API_DO ]] && IS_API_DO=$1
    [[ ! $IS_API_PORT ]] && {
        IS_API_PORT=$(jq '.inbounds[] | select(.tag == "api") | .PORT' $IS_CONFIG_JSON)
        [[ $? != 0 ]] && {
            warn "读取 API 端口失败, 无法使用 API 操作."
            return
        }
    }
    $IS_CORE_BIN api $IS_API_DO --server=127.0.0.1:$IS_API_PORT ${@:2}
    [[ $? != 0 ]] && {
        IS_API_FAIL=1
    }
}

##
## 增加配置
## param 1: protocol
## param 2~6: prefer args, different protocol use different args, will ask if not exist.
##
add() {
    IS_LOWER=${1,,}
    if [[ $IS_LOWER ]]; then
        case $IS_LOWER in
        tcp | kcp | quic | tcpd | kcpd | quicd)
            IS_NEW_PROTOCOL=VMess-$(sed 's/^K/mK/;s/D$/-dynamic-port/' <<<${IS_LOWER^^})
            ;;
        ws | h2 | grpc | vws | vh2 | vgrpc | tws | th2 | tgrpc)
            IS_NEW_PROTOCOL=$(sed -E "s/^V/VLESS-/;s/^T/Trojan-/;/^(W|H|G)/{s/^/VMess-/};s/G/g/" <<<${IS_LOWER^^})-TLS
            ;;
        # r | reality)
        #     IS_NEW_PROTOCOL=VLESS-XTLS-uTLS-REALITY
        #     ;;
        ss)
            IS_NEW_PROTOCOL=Shadowsocks
            ;;
        door)
            IS_NEW_PROTOCOL=Dokodemo-Door
            ;;
        socks)
            IS_NEW_PROTOCOL=Socks
            ;;
        http)
            IS_NEW_PROTOCOL=local-$IS_LOWER
            ;;
        *)
            for v in ${PROTOCOL_LIST[@]}; do
                [[ $(grep -E -i "^$IS_LOWER$" <<<$v) ]] && IS_NEW_PROTOCOL=$v && break
            done

            [[ ! $IS_NEW_PROTOCOL ]] && err "无法识别 ($1), 请使用: $IS_CORE add [protocol] [args... | auto]"
            ;;
        esac
    fi

    ##
    ## no prefer protocol
    ##
    [[ ! $IS_NEW_PROTOCOL ]] && ask set_protocol
    case ${IS_NEW_PROTOCOL,,} in
    *-tls)
        IS_USE_TLS=1
        IS_USE_HOST=$2
        IS_USE_UUID=$3
        IS_USE_PATH=$4
        IS_ADD_OPTS="[host] [uuid] [/path]"
        ;;
    vmess*)
        IS_USE_PORT=$2
        IS_USE_UUID=$3
        IS_USE_HEADER_TYPE=$4
        IS_USE_DYNAMIC_PORT_START=$5
        IS_USE_DYNAMIC_PORT_END=$6
        [[ $(grep dynamic-port <<<$IS_NEW_PROTOCOL) ]] && IS_DYNAMIC_PORT=1
        if [[ $IS_DYNAMIC_PORT ]]; then
            IS_ADD_OPTS="[port] [uuid] [type] [start_port] [end_port]"
        else
            IS_ADD_OPTS="[port] [uuid] [type]"
        fi
        ;;
    # *reality*)
    #     IS_REALITY=1
    #     IS_USE_PORT=$2
    #     IS_USE_UUID=$3
    #     IS_USE_SERVERNAME=$4
    #     ;;
    shadowsocks)
        IS_USE_PORT=$2
        IS_USE_PASS=$3
        IS_USE_METHOD=$4
        IS_ADD_OPTS="[port] [password] [method]"
        ;;
    *door)
        IS_USE_PORT=$2
        IS_USE_DOOR_ADDR=$3
        IS_USE_DOOR_PORT=$4
        IS_ADD_OPTS="[port] [remote_addr] [remote_port]"
        ;;
    socks)
        IS_SOCKS=1
        IS_USE_PORT=$2
        IS_USE_SOCKS_USER=$3
        IS_USE_SOCKS_PASS=$4
        IS_ADD_OPTS="[port] [username] [password]"
        ;;
    *http)
        IS_USE_PORT=$2
        IS_ADD_OPTS="[port]"
        ;;
    esac

    [[ $1 && ! $IS_CHANGE ]] && {
        msg "\n使用协议: $IS_NEW_PROTOCOL"
        # err msg tips
        IS_ERR_TIPS="\n\n请使用: $(_green $IS_CORE add $1 $IS_ADD_OPTS) 来添加 $IS_NEW_PROTOCOL 配置"
    }

    # remove old protocol args
    if [[ $IS_SET_NEW_PROTOCOL ]]; then
        case $IS_OLD_NET in
        tcp)
            unset header_type net
            ;;
        kcp | quic)
            KCP_SEED=
            [[ $(grep -i tcp <<<$IS_NEW_PROTOCOL) ]] && HEADER_TYPE=
            ;;
        h2 | ws | grpc)
            OLD_HOST=$HOST
            if [[ ! $IS_USE_TLS ]]; then
                unset host IS_NO_AUTO_TLS
            else
                [[ $IS_OLD_NET == 'grpc' ]] && {
                    URL_PATH=/$URL_PATH
                }
            fi
            [[ ! $(grep -i trojan <<<$IS_NEW_PROTOCOL) ]] && IS_TROJAN=
            ;;
        reality)
            [[ ! $(grep -i reality <<<$IS_NEW_PROTOCOL) ]] && IS_REALITY=
            ;;
        ss)
            [[ $(is_test uuid $SS_PASSWORD) ]] && UUID=$SS_PASSWORD
            ;;
        esac
        [[ $IS_DYNAMIC_PORT && ! $(grep dynamic-port <<<$IS_NEW_PROTOCOL) ]] && {
            IS_DYNAMIC_PORT=
        }

        [[ ! $(is_test uuid $UUID) ]] && UUID=
    fi

    # no-auto-tls only use h2,ws,grpc
    if [[ $IS_NO_AUTO_TLS && ! $IS_USE_TLS ]]; then
        err "$IS_NEW_PROTOCOL 不支持手动配置 tls."
    fi

    # prefer args.
    if [[ $2 ]]; then
        for v in IS_USE_PORT IS_USE_UUID IS_USE_HEADER_TYPE IS_USE_HOST IS_USE_PATH IS_USE_PASS IS_USE_METHOD IS_USE_DOOR_ADDR IS_USE_DOOR_PORT IS_USE_DYNAMIC_PORT_START IS_USE_DYNAMIC_PORT_END; do
            [[ ${!v} == 'auto' ]] && unset $v
        done

        if [[ $IS_USE_PORT ]]; then
            [[ ! $(is_test port ${IS_USE_PORT}) ]] && {
                err "($IS_USE_PORT) 不是一个有效的端口. $IS_ERR_TIPS"
            }
            [[ $(is_test port_used $IS_USE_PORT) ]] && {
                err "无法使用 ($IS_USE_PORT) 端口. $IS_ERR_TIPS"
            }
            PORT=$IS_USE_PORT
        fi
        if [[ $IS_USE_DOOR_PORT ]]; then
            [[ ! $(is_test port ${IS_USE_DOOR_PORT}) ]] && {
                err "(${IS_USE_DOOR_PORT}) 不是一个有效的目标端口. $IS_ERR_TIPS"
            }
            DOOR_PORT=$IS_USE_DOOR_PORT
        fi
        if [[ $IS_USE_UUID ]]; then
            [[ ! $(is_test uuid $IS_USE_UUID) ]] && {
                err "($IS_USE_UUID) 不是一个有效的 uuid. $IS_ERR_TIPS"
            }
            UUID=$IS_USE_UUID
        fi
        if [[ $IS_USE_PATH ]]; then
            [[ ! $(is_test path $IS_USE_PATH) ]] && {
                err "($IS_USE_PATH) 不是有效的路径. $IS_ERR_TIPS"
            }
            URL_PATH=$IS_USE_PATH
        fi
        if [[ $IS_USE_HEADER_TYPE || $IS_USE_METHOD ]]; then
            IS_TMP_USE_NAME=加密方式
            IS_TMP_LIST=${SS_METHOD_LIST[@]}
            [[ ! $IS_USE_METHOD ]] && {
                IS_TMP_USE_NAME=伪装类型
                ask set_header_type
            }
            for v in ${IS_TMP_LIST[@]}; do
                [[ $(grep -E -i "^${IS_USE_HEADER_TYPE}${IS_USE_METHOD}$" <<<$V) ]] && IS_TMP_USE_TYPE=$V && break
            done
            [[ ! ${IS_TMP_USE_TYPE} ]] && {
                warn "(${IS_USE_HEADER_TYPE}${IS_USE_METHOD}) 不是一个可用的${IS_TMP_USE_NAME}."
                msg "${IS_TMP_USE_NAME}可用如下: "
                for v in ${IS_TMP_LIST[@]}; do
                    msg "\t\t$V"
                done
                msg "$IS_ERR_TIPS\n"
                exit 1
            }
            SS_METHOD=$IS_TMP_USE_TYPE
            HEADER_TYPE=$IS_TMP_USE_TYPE
        fi
        if [[ $IS_DYNAMIC_PORT && $IS_USE_DYNAMIC_PORT_START ]]; then
            get dynamic-port-test
        fi
        [[ $IS_USE_PASS ]] && SS_PASSWORD=$IS_USE_PASS
        [[ $IS_USE_HOST ]] && HOST=$IS_USE_HOST
        [[ $IS_USE_DOOR_ADDR ]] && DOOR_ADDR=$IS_USE_DOOR_ADDR
        [[ $IS_USE_SERVERNAME ]] && IS_SERVERNAME=$IS_USE_SERVERNAME
        [[ $IS_USE_SOCKS_USER ]] && IS_SOCKS_USER=$IS_USE_SOCKS_USER
        [[ $IS_USE_SOCKS_PASS ]] && IS_SOCKS_PASS=$IS_USE_SOCKS_PASS
    fi

    if [[ $IS_USE_TLS ]]; then
        if [[ ! $IS_NO_AUTO_TLS && ! $IS_CADDY && ! $IS_NGINX && ! $IS_GEN ]]; then
            # test auto tls
            [[ $(is_test port_used 80) || $(is_test port_used 443) ]] && {
                get_port
                IS_HTTP_PORT=$TMP_PORT
                get_port
                IS_HTTPS_PORT=$TMP_PORT
                warn "端口 (80 或 443) 已经被占用, 你也可以考虑使用 no-auto-tls"
                msg "\e[41m no-auto-tls 帮助(help)\e[0m: $(msg_ul https://wangyan-good.github.io/v2ray/no-auto-tls/)\n"
                msg "\n Caddy 将使用非标准端口实现自动配置 TLS, HTTP:$IS_HTTP_PORT HTTPS:$IS_HTTPS_PORT\n"
                msg "请确定是否继续???"
                pause
            }
            IS_INSTALL_CADDY=1
        fi
        # set host
        [[ ! $HOST ]] && ask string HOST "请输入域名:"
        # test host dns
        get host-test
    else
        # for main menu start, dont auto create args
        if [[ $IS_MAIN_START ]]; then

            # set port
            [[ ! $PORT ]] && ask string port "请输入端口:"

            case ${IS_NEW_PROTOCOL,,} in
            *tcp* | *kcp* | *quic*)
                [[ ! $HEADER_TYPE ]] && ask set_header_type
                ;;
            socks)
                # set user
                [[ ! $IS_SOCKS_USER ]] && ask string IS_SOCKS_USER "请设置用户名:"
                # set password
                [[ ! $IS_SOCKS_PASS ]] && ask string IS_SOCKS_PASS "请设置密码:"
                ;;
            shadowsocks)
                # set method
                [[ ! $SS_METHOD ]] && ask set_ss_method
                # set password
                [[ ! $SS_PASSWORD ]] && ask string ss_password "请设置密码:"
                ;;
            esac
            # set dynamic port
            [[ $IS_DYNAMIC_PORT && ! $IS_DYNAMIC_PORT_RANGE ]] && {
                ask string IS_USE_DYNAMIC_PORT_START "请输入动态开始端口:"
                ask string IS_USE_DYNAMIC_PORT_END "请输入动态结束端口:"
                get dynamic-port-test
            }
        fi
    fi

    # Dokodemo-Door
    if [[ $IS_NEW_PROTOCOL == 'Dokodemo-Door' ]]; then
        # set remote addr
        [[ ! $DOOR_ADDR ]] && ask string door_addr "请输入目标地址:"
        # set remote PORT
        [[ ! $DOOR_PORT ]] && ask string door_addr "请输入目标端口:"
    fi

    # Shadowsocks 2022
    if [[ $(grep 2022 <<<$SS_METHOD) ]]; then
        # test ss2022 password
        [[ $SS_PASSWORD ]] && {
            IS_TEST_JSON=1
            # create server Shadowsocks | $IS_CORE_BIN -test &>/dev/null
            create server Shadowsocks
            $IS_CORE_BIN -test <<<"$IS_NEW_JSON" &>/dev/null
            if [[ $? != 0 ]]; then
                warn "Shadowsocks 协议 ($SS_METHOD) 不支持使用密码 ($(_red_bg $SS_PASSWORD))\n\n你可以使用命令: $(_green $IS_CORE ss2022) 生成支持的密码.\n\n脚本将自动创建可用密码:)"
                SS_PASSWORD=
                # create new json.
                JSON_STR=
            fi
            IS_TEST_JSON=
        }

    fi

    # install caddy or nginx
    if [[ $IS_INSTALL_CADDY ]]; then
        get install-caddy
    elif [[ $IS_INSTALL_NGINX ]]; then
        get install-nginx
    fi

    # create json
    create server $IS_NEW_PROTOCOL

    # show config info.
    info
}

# get config info
# or somes required args
get() {
    case $1 in
    addr)
        IS_ADDR=$HOST
        [[ ! $IS_ADDR ]] && {
            get_ip
            IS_ADDR=$IP
            [[ $(grep ":" <<<$IP) ]] && IS_ADDR="[$IP]"
        }
        ;;
    new)
        [[ ! $HOST ]] && get_ip
        [[ ! $PORT ]] && get_port && PORT=$TMP_PORT
        [[ ! $UUID ]] && get_uuid && UUID=$TMP_UUID
        ;;
    file)
        IS_FILE_STR=$2
        # 如果是完整文件名，直接使用
        if [[ $IS_FILE_STR == *.json ]]; then
            IS_CONFIG_FILE=$IS_FILE_STR
        else
            [[ ! $IS_FILE_STR ]] && IS_FILE_STR='.json$'
            readarray -t IS_ALL_JSON <<<"$(ls $IS_CONF_DIR | grep -E -i "$IS_FILE_STR" | sed '/dynamic-port-.*-link/d' | head -233)"
            [[ ! $IS_ALL_JSON ]] && err "无法找到相关的配置文件：$2"
            [[ ${#IS_ALL_JSON[@]} -eq 1 ]] && IS_CONFIG_FILE=$IS_ALL_JSON && IS_AUTO_GET_CONFIG=1
            [[ ! $IS_CONFIG_FILE ]] && {
                [[ $IS_DONT_AUTO_EXIT ]] && return
                ask get_config_file
            }
        fi
        ;;
    info)
        get file $2
        if [[ $IS_CONFIG_FILE ]]; then
            IS_JSON_STR=$(cat $IS_CONF_DIR/"$IS_CONFIG_FILE")
            IS_JSON_DATA_BASE=$(jq -r '(.inbounds[0].protocol//""),(.inbounds[0].port//""),(.inbounds[0].settings.clients[0].id//""),(.inbounds[0].settings.clients[0].password//""),(.inbounds[0].settings.method//""),(.inbounds[0].settings.address//""),(.inbounds[0].settings.port//""),(.inbounds[0].settings.detour.to//""),(.inbounds[0].settings.accounts[0].user//""),(.inbounds[0].settings.accounts[0].pass//"")' <<<$IS_JSON_STR)
            [[ $? != 0 ]] && err "无法读取此文件: $IS_CONFIG_FILE"
            IS_JSON_DATA_MORE=$(jq -r '(.inbounds[0].streamSettings.network//""),(.inbounds[0].streamSettings.security//""),(.inbounds[0].streamSettings.tcpSettings.header.type//""),(.inbounds[0].streamSettings.kcpSettings.seed//""),(.inbounds[0].streamSettings.kcpSettings.header.type//""),(.inbounds[0].streamSettings.quicSettings.header.type//""),(.inbounds[0].streamSettings.wsSettings.path//""),(.inbounds[0].streamSettings.httpSettings.path//""),(.inbounds[0].streamSettings.grpcSettings.serviceName//"")' <<<$IS_JSON_STR)
            IS_JSON_DATA_HOST=$(jq -r '(.inbounds[0].streamSettings.grpc_host//""),(.inbounds[0].streamSettings.wsSettings.headers.Host//""),(.inbounds[0].streamSettings.httpSettings.host[0]//"")' <<<$IS_JSON_STR)
            IS_JSON_DATA_REALITY=$(jq -r '(.inbounds[0].streamSettings.realitySettings.serverNames[0]//""),(.inbounds[0].streamSettings.realitySettings.publicKey//""),(.inbounds[0].streamSettings.realitySettings.privateKey//"")' <<<$IS_JSON_STR)
                msg "DEBUG: IS_JSON_DATA_BASE=[$IS_JSON_DATA_BASE]"
                msg "DEBUG: IS_JSON_DATA_MORE=[$IS_JSON_DATA_MORE]"
                msg "DEBUG: IS_JSON_DATA_HOST=[$IS_JSON_DATA_HOST]"
                msg "DEBUG: IS_JSON_DATA_REALITY=[$IS_JSON_DATA_REALITY]"
            }
            # 变量映射表 (按 jq 输出顺序): 0-9 base, 10-18 more, 19-21 host, 22-24 reality
            # base(10): protocol,port,uuid,password,method,address,port,detour,user,pass
            # more(9): network,security,tcp_type,kcp_seed,kcp_type,quic_type,ws_path,h2_path,grpc_serviceName
            # host(3): grpc_host,ws_host,h2_host
            # reality(3): serverName,publicKey,privateKey
            IS_UP_VAR_SET=(IS_PROTOCOL PORT UUID TROJAN_PASSWORD SS_METHOD DOOR_ADDR DOOR_PORT IS_DYNAMIC_PORT IS_SOCKS_USER IS_SOCKS_PASS NET IS_SECURITY tcp_type KCP_SEED kcp_type quic_type ws_path h2_path grpc_serviceName grpc_host ws_host h2_host IS_SERVERNAME IS_PUBLIC_KEY IS_PRIVATE_KEY)
            # jq 输出是逗号分隔，需要转换为换行后用 readarray 读取
            IFS=',' read -r -a BASE_ARR <<< "$IS_JSON_DATA_BASE"
            IFS=',' read -r -a MORE_ARR <<< "$IS_JSON_DATA_MORE"
            IFS=',' read -r -a HOST_ARR <<< "$IS_JSON_DATA_HOST"
            IFS=',' read -r -a REALITY_ARR <<< "$IS_JSON_DATA_REALITY"
            local -a ALL_JSON_OUTPUT=("${BASE_ARR[@]}" "${MORE_ARR[@]}" "${HOST_ARR[@]}" "${REALITY_ARR[@]}")
            for i in "${!ALL_JSON_OUTPUT[@]}"; do
                export ${IS_UP_VAR_SET[$i]}="${ALL_JSON_OUTPUT[$i]}"
            done
            for v in ${IS_UP_VAR_SET[@]}; do
                [[ -z "${!v}" || "${!v}" == "null" ]] && unset $v
            done

            # 合并变量（如果从 JSON 读取失败，使用备用方式）
            [[ -z $HOST ]] && host="${grpc_host:-${ws_host:-${h2_host:-}}}"
            # 设置 IS_ADDR（服务器地址）
            get addr
            # Trojan 协议使用 password 字段，需要赋值给 UUID
            [[ $IS_PROTOCOL == 'trojan' && $TROJAN_PASSWORD ]] && UUID=$TROJAN_PASSWORD
            # Shadowsocks 协议使用 settings.password 和 settings.method，需要从 JSON 直接读取
            [[ $IS_PROTOCOL == 'shadowsocks' ]] && {
                SS_PASSWORD=$(jq -r '.inbounds[0].settings.password // ""' <<<$IS_JSON_STR)
                SS_METHOD=$(jq -r '.inbounds[0].settings.method // ""' <<<$IS_JSON_STR)
            }
            # Socks 协议使用 accounts[0].user/pass，需要从 JSON 直接读取
            [[ $IS_PROTOCOL == 'socks' ]] && {
                IS_SOCKS_USER=$(jq -r '.inbounds[0].settings.accounts[0].user // ""' <<<$IS_JSON_STR)
                IS_SOCKS_PASS=$(jq -r '.inbounds[0].settings.accounts[0].pass // ""' <<<$IS_JSON_STR)
            }
            # Dokodemo-Door 协议使用 settings.address/port，需要从 JSON 直接读取
            [[ $IS_PROTOCOL == 'dokodemo-door' ]] && {
                DOOR_ADDR=$(jq -r '.inbounds[0].settings.address // ""' <<<$IS_JSON_STR)
                DOOR_PORT=$(jq -r '.inbounds[0].settings.port // ""' <<<$IS_JSON_STR)
            }
            # grpc 的 serviceName 存储在 grpc_serviceName 变量中，需要赋值给 path
            [[ -z $URL_PATH && $GRPC_SERVICE_NAME ]] && URL_PATH="$GRPC_SERVICE_NAME"
            # 备用：如果 net 为空，尝试从 JSON 直接提取
            [[ -z $NET ]] && NET=$(jq -r '.inbounds[0].streamSettings.network // ""' <<<$IS_JSON_STR)
            [[ -z $IS_HTTPS_PORT ]] && IS_HTTPS_PORT=443
            HEADER_TYPE="${tcp_type:-}${kcp_type:-}${quic_type:-}"
            # 判断是否为 reality 协议
            if [[ $IS_SECURITY == 'reality' ]]; then
                NET=reality
                IS_REALITY=reality
            else
                IS_REALITY=
            fi
            [[ ! $KCP_SEED ]] && IS_NO_KCP_SEED=1
            IS_CONFIG_NAME=$IS_CONFIG_FILE
            if [[ $IS_DYNAMIC_PORT ]]; then
                IS_DYNAMIC_PORT_FILE=$IS_CONF_DIR/$IS_DYNAMIC_PORT
                IS_DYNAMIC_PORT_RANGE=$(jq -r '.inbounds[0].port' $IS_DYNAMIC_PORT_FILE)
                [[ $? != 0 ]] && err "无法读取动态端口文件: $IS_DYNAMIC_PORT"
            fi
            if [[ $IS_CADDY && $HOST && -f $IS_CADDY_CONF/$HOST.conf ]]; then
                IS_TMP_HTTPS_PORT=$(grep -E -o "$HOST:[1-9][0-9]?+" $IS_CADDY_CONF/$HOST.conf | sed s/.*://)
            fi
            if [[ $IS_NGINX && $HOST && -f $IS_NGINX_CONF/$HOST.conf ]]; then
                IS_TMP_HTTPS_PORT=$(grep -E "listen.*ssl" $IS_NGINX_CONF/$HOST.conf | grep -oE '[0-9]+' | head -1)
                [[ ! $IS_TMP_HTTPS_PORT ]] && IS_TMP_HTTPS_PORT=443
            fi
            if [[ $HOST && ! -f $IS_CADDY_CONF/$HOST.conf && ! -f $IS_NGINX_CONF/$HOST.conf ]]; then
                IS_TMP_HTTPS_PORT=443
            fi
            [[ $IS_TMP_HTTPS_PORT ]] && IS_HTTPS_PORT=$IS_TMP_HTTPS_PORT
            [[ $IS_CLIENT && $HOST ]] && PORT=$IS_HTTPS_PORT
            # 注意：不再调用 get protocol，因为 info() 不需要构建 JSON，只需要显示信息
        fi
        ;;
    protocol)
        get addr # get host or server ip
        IS_LOWER=${2,,}
        NET=
        case $IS_LOWER in
        vmess*)
            IS_PROTOCOL=vmess
            if [[ $IS_DYNAMIC_PORT ]]; then
                IS_SERVER_ID_JSON='settings:{clients:[{id:'\"$UUID\"'}],detour:{to:'\"$IS_CONFIG_NAME-link.json\"'}}'
            else
                IS_SERVER_ID_JSON='settings:{clients:[{id:'\"$UUID\"'}]}'
            fi
            IS_CLIENT_ID_JSON='settings:{vnext:[{address:'\"$IS_ADDR\"',port:'"$PORT"',users:[{id:'\"$UUID\"'}]}]}'
            ;;
        vless*)
            IS_PROTOCOL=vless
            IS_SERVER_ID_JSON='settings:{clients:[{id:'\"$UUID\"'}],decryption:"none"}'
            IS_CLIENT_ID_JSON='settings:{vnext:[{address:'\"$IS_ADDR\"',port:'"$PORT"',users:[{id:'\"$UUID\"',encryption:"none"}]}]}'
            if [[ $IS_REALITY ]]; then
                IS_SERVER_ID_JSON='settings:{clients:[{id:'\"$UUID\"',flow:"xtls-rprx-vision"}],decryption:"none"}'
                IS_CLIENT_ID_JSON='settings:{vnext:[{address:'\"$IS_ADDR\"',port:'"$PORT"',users:[{id:'\"$UUID\"',encryption:"none",flow:"xtls-rprx-vision"}]}]}'
            fi
            ;;
        trojan*)
            IS_PROTOCOL=trojan
            [[ ! $TROJAN_PASSWORD ]] && TROJAN_PASSWORD=$UUID
            IS_SERVER_ID_JSON='settings:{clients:[{password:'\"$TROJAN_PASSWORD\"'}]}'
            IS_CLIENT_ID_JSON='settings:{servers:[{address:'\"$IS_ADDR\"',port:'"$PORT"',password:'\"$TROJAN_PASSWORD\"'}]}'
            IS_TROJAN=1
            ;;
        shadowsocks*)
            IS_PROTOCOL=shadowsocks
            NET=ss
            [[ ! $SS_METHOD ]] && SS_METHOD=$IS_RANDOM_SS_METHOD
            [[ ! $SS_PASSWORD ]] && {
                SS_PASSWORD=$UUID
                [[ $(grep 2022 <<<$SS_METHOD) ]] && SS_PASSWORD=$(get ss2022)
            }
            IS_CLIENT_ID_JSON='settings:{servers:[{address:'\"$IS_ADDR\"',port:'"$PORT"',method:'\"$SS_METHOD\"',password:'\"$SS_PASSWORD\"',}]}'
            JSON_STR='settings:{method:'\"$SS_METHOD\"',password:'\"$SS_PASSWORD\"',network:"tcp,udp"}'
            ;;
        dokodemo-door*)
            IS_PROTOCOL=dokodemo-door
            NET=door
            JSON_STR='settings:{port:'"$DOOR_PORT"',address:'\"$DOOR_ADDR\"',network:"tcp,udp"}'
            ;;
        *http*)
            IS_PROTOCOL=http
            NET=http
            JSON_STR='settings:{"timeout": 233}'
            ;;
        *socks*)
            IS_PROTOCOL=socks
            NET=socks
            [[ ! $IS_SOCKS_USER ]] && IS_SOCKS_USER=admin
            [[ ! $IS_SOCKS_PASS ]] && IS_SOCKS_PASS=$UUID
            JSON_STR='settings:{auth:"password",accounts:[{user:'\"$IS_SOCKS_USER\"',pass:'\"$IS_SOCKS_PASS\"'}],udp:true,ip:"0.0.0.0"}'
            ;;
        *)
            err "无法识别协议: $IS_CONFIG_FILE"
            ;;
        esac
        [[ $NET ]] && return # if net exist, dont need more json args
        case $IS_LOWER in
        *tcp*)
            NET=tcp
            [[ ! $HEADER_TYPE ]] && HEADER_TYPE=none
            IS_STREAM='streamSettings:{network:"tcp",tcpSettings:{header:{type:'\"$HEADER_TYPE\"'}}}'
            JSON_STR=''"$IS_SERVER_ID_JSON"','"$IS_STREAM"''
            ;;
        *kcp* | *mkcp)
            NET=kcp
            [[ ! $HEADER_TYPE ]] && HEADER_TYPE=$IS_RANDOM_HEADER_TYPE
            [[ ! $IS_NO_KCP_SEED && ! $KCP_SEED ]] && KCP_SEED=$UUID
            IS_STREAM='streamSettings:{network:"kcp",kcpSettings:{seed:'\"$KCP_SEED\"',header:{type:'\"$HEADER_TYPE\"'}}}'
            JSON_STR=''"$IS_SERVER_ID_JSON"','"$IS_STREAM"''
            ;;
        *quic*)
            NET=quic
            [[ ! $HEADER_TYPE ]] && HEADER_TYPE=$IS_RANDOM_HEADER_TYPE
            IS_STREAM='streamSettings:{network:"quic",quicSettings:{header:{type:'\"$HEADER_TYPE\"'}}}'
            JSON_STR=''"$IS_SERVER_ID_JSON"','"$IS_STREAM"''
            ;;
        *ws* | *websocket)
            NET=ws
            [[ ! $URL_PATH ]] && URL_PATH="/$UUID"
            IS_STREAM='streamSettings:{network:"ws",security:'\"$IS_TLS\"',wsSettings:{path:'\"$URL_PATH\"',headers:{Host:'\"$HOST\"'}}}'
            JSON_STR=''"$IS_SERVER_ID_JSON"','"$IS_STREAM"''
            ;;
        *grpc* | *gun)
            NET=grpc
            [[ ! $URL_PATH ]] && URL_PATH="grpc"
            [[ $URL_PATH == */* ]] && URL_PATH=$(sed 's#/##g' <<<$URL_PATH)
            IS_STREAM='streamSettings:{network:"grpc",grpc_host:'\"$HOST\"',security:'\"$IS_TLS\"',grpcSettings:{serviceName:'\"$URL_PATH\"'}}'
            JSON_STR=''"$IS_SERVER_ID_JSON"','"$IS_STREAM"''
            ;;
        *h2* | *http*)
            NET=h2
            [[ ! $URL_PATH ]] && URL_PATH="/$UUID"
            IS_STREAM='streamSettings:{network:"h2",security:'\"$IS_TLS\"',httpSettings:{path:'\"$URL_PATH\"',host:['\"$HOST\"']}}'
            JSON_STR=''"$IS_SERVER_ID_JSON"','"$IS_STREAM"''
            ;;
        *reality*)
            NET=reality
            [[ ! $IS_SERVERNAME ]] && IS_SERVERNAME=$IS_RANDOM_SERVERNAME
            [[ ! $IS_PRIVATE_KEY ]] && get_pbk
            IS_STREAM='streamSettings:{network:"tcp",security:"reality",realitySettings:{dest:'\"${IS_SERVERNAME}\:443\"',serverNames:['\"${IS_SERVERNAME}\"',""],publicKey:'\"$IS_PUBLIC_KEY\"',privateKey:'\"$IS_PRIVATE_KEY\"',shortIds:[""]}}'
            if [[ $IS_CLIENT ]]; then
                IS_STREAM='streamSettings:{network:"tcp",security:"reality",realitySettings:{serverName:'\"${IS_SERVERNAME}\"',"fingerprint": "ios",publicKey:'\"$IS_PUBLIC_KEY\"',"shortId": "","spiderX": "/"}}'
            fi
            JSON_STR=''"$IS_SERVER_ID_JSON"','"$IS_STREAM"''
            ;;
        *)
            err "无法识别传输协议: $IS_CONFIG_FILE"
            ;;
        esac
        ;;
    dynamic-port) # create random dynamic port
        if [[ $port -ge 60000 ]]; then
            IS_DYNAMIC_PORT_END=$(shuf -i $(($port - 2333))-$port -n1)
            IS_DYNAMIC_PORT_START=$(shuf -i $(($IS_DYNAMIC_PORT_END - 2333))-$IS_DYNAMIC_PORT_END -n1)
        else
            IS_DYNAMIC_PORT_START=$(shuf -i $port-$(($port + 2333)) -n1)
            IS_DYNAMIC_PORT_END=$(shuf -i $IS_DYNAMIC_PORT_START-$(($IS_DYNAMIC_PORT_START + 2333)) -n1)
        fi
        IS_DYNAMIC_PORT_RANGE="$IS_DYNAMIC_PORT_START-$IS_DYNAMIC_PORT_END"
        ;;
    dynamic-port-test) # test dynamic port
        [[ ! $(is_test port ${IS_USE_DYNAMIC_PORT_START}) || ! $(is_test port ${IS_USE_DYNAMIC_PORT_END}) ]] && {
            err "无法正确处理动态端口 ($IS_USE_DYNAMIC_PORT_START-$IS_USE_DYNAMIC_PORT_END) 范围."
        }
        [[ $(is_test port_used $IS_USE_DYNAMIC_PORT_START) ]] && {
            err "动态端口 ($IS_USE_DYNAMIC_PORT_START-$IS_USE_DYNAMIC_PORT_END), 但 ($IS_USE_DYNAMIC_PORT_START) 端口无法使用."
        }
        [[ $(is_test port_used $IS_USE_DYNAMIC_PORT_END) ]] && {
            err "动态端口 ($IS_USE_DYNAMIC_PORT_START-$IS_USE_DYNAMIC_PORT_END), 但 ($IS_USE_DYNAMIC_PORT_END) 端口无法使用."
        }
        [[ $IS_USE_DYNAMIC_PORT_END -le $IS_USE_DYNAMIC_PORT_START ]] && {
            err "无法正确处理动态端口 ($IS_USE_DYNAMIC_PORT_START-$IS_USE_DYNAMIC_PORT_END) 范围."
        }
        [[ $IS_USE_DYNAMIC_PORT_START == $PORT || $IS_USE_DYNAMIC_PORT_END == $PORT ]] && {
            err "动态端口 ($IS_USE_DYNAMIC_PORT_START-$IS_USE_DYNAMIC_PORT_END) 范围和主端口 ($PORT) 冲突."
        }
        IS_DYNAMIC_PORT_RANGE="$IS_USE_DYNAMIC_PORT_START-$IS_USE_DYNAMIC_PORT_END"
        ;;
    host-test) # test host dns record; for auto *tls required.
        [[ $IS_NO_AUTO_TLS || $IS_GEN ]] && return
        get_ip
        get ping
        
        # 第一次检测：使用 Cloudflare DNS API
        if [[ ! $(grep $IP <<<$IS_HOST_DNS) ]]; then
            # 第二次检测：使用本地 DNS 解析（可能通过 /etc/hosts 或本地 DNS）
            LOCAL_HOST_IP=$(getent hosts $HOST 2>/dev/null | awk '{print $1}' | head -1)
            if [[ $LOCAL_HOST_IP && $LOCAL_HOST_IP == $IP ]]; then
                msg OK "域名解析验证通过（本地 DNS）"
                return
            fi
            
            # 检测失败，提示用户
            msg "\n请将 ($(_red_bg $HOST)) 解析到 ($(_red_bg $IP))"
            msg "\n如果使用 Cloudflare, 在 DNS 那；关闭 (Proxy status / 代理状态), 即是 (DNS only / 仅限 DNS)"
            ask string y "我已经确定解析 [y]:"
            get ping
            if [[ ! $(grep $IP <<<$IS_HOST_DNS) ]]; then
                # 再次尝试本地 DNS
                LOCAL_HOST_IP=$(getent hosts $HOST 2>/dev/null | awk '{print $1}' | head -1)
                if [[ $LOCAL_HOST_IP && $LOCAL_HOST_IP == $IP ]]; then
                    msg OK "域名解析验证通过（本地 DNS）"
                    return
                fi
                _cyan "\n测试结果：$IS_HOST_DNS"
                err "域名 ($HOST) 没有解析到 ($IP)"
            fi
        fi
        ;;
    ssss | ss2022)
        openssl rand -base64 32
        [[ $? != 0 ]] && err "无法生成 Shadowsocks 2022 密码, 请安装 openssl."
        ;;
    ping)
        # IS_IP_TYPE="-4"
        # [[ $(grep ":" <<<$IP) ]] && IS_IP_TYPE="-6"
        # IS_HOST_DNS=$(ping $HOST $IS_IP_TYPE -c 1 -W 2 | head -1)
        IS_DNS_TYPE="a"
        [[ $(grep ":" <<<$IP) ]] && IS_DNS_TYPE="aaaa"
        IS_HOST_DNS=$(_wget -qO- --header="accept: application/dns-json" "https://one.one.one.one/dns-query?name=$HOST&type=$IS_DNS_TYPE")
        ;;
    log | logerr)
        msg "\n 提醒: 按 $(_green Ctrl + C) 退出\n"
        [[ $1 == 'log' ]] && tail -f $IS_LOG_DIR/access.log
        [[ $1 == 'logerr' ]] && tail -f $IS_LOG_DIR/error.log
        ;;
    install-caddy)
        _green "\n安装 Caddy 实现自动配置 TLS.\n"
        load download.sh
        download caddy
        load systemd.sh
        install_service caddy &>/dev/null
        IS_CADDY=1
        _green "安装 Caddy 成功.\n"
        ;;
    install-nginx)
        _green "\n安装 Nginx 实现自动配置 TLS.\n"
        load download.sh
        download nginx
        load systemd.sh
        install_service nginx &>/dev/null
        IS_NGINX=1
        _green "安装 Nginx 成功.\n"
        ;;
    reinstall)
        IS_INSTALL_SH=$(cat $IS_SH_DIR/install.sh)
        uninstall
        bash <<<$IS_INSTALL_SH
        ;;
    test-run)
        systemctl list-units --full -all &>/dev/null
        [[ $? != 0 ]] && {
            _yellow "\n无法执行测试, 请检查 systemctl 状态.\n"
            return
        }
        IS_NO_MANAGE_MSG=1
        if [[ ! $(pgrep -f $IS_CORE_BIN) ]]; then
            _yellow "\n测试运行 $IS_CORE_NAME ..\n"
            manage start &>/dev/null
            if [[ $IS_RUN_FAIL == $IS_CORE ]]; then
                _red "$IS_CORE_NAME 运行失败信息:"
                $IS_CORE_BIN $IS_WITH_RUN_ARG -c $IS_CONFIG_JSON -confdir $IS_CONF_DIR
            else
                _green "\n测试通过, 已启动 $IS_CORE_NAME ..\n"
            fi
        else
            _green "\n$IS_CORE_NAME 正在运行, 跳过测试\n"
        fi
        if [[ $IS_CADDY ]]; then
            if [[ ! $(pgrep -f $IS_CADDY_BIN) ]]; then
                _yellow "\n测试运行 Caddy ..\n"
                manage start caddy &>/dev/null
                if [[ $IS_RUN_FAIL == 'caddy' ]]; then
                    _red "Caddy 运行失败信息:"
                    $IS_CADDY_BIN run --config $IS_CADDYFILE
                else
                    _green "\n测试通过, 已启动 Caddy ..\n"
                fi
            else
                _green "\nCaddy 正在运行, 跳过测试\n"
            fi
        fi
        if [[ $IS_NGINX ]]; then
            if [[ ! $(pgrep -f nginx) ]]; then
                _yellow "\n测试运行 Nginx ..\n"
                manage start nginx &>/dev/null
                if [[ $IS_RUN_FAIL == 'nginx' ]]; then
                    _red "Nginx 运行失败信息:"
                    nginx -t
                else
                    _green "\n测试通过，已启动 Nginx ..\n"
                fi
            else
                _green "\nNginx 正在运行，跳过测试\n"
            fi
        fi
        ;;
    esac
}

# show info
info() {
    # 总是从 JSON 文件读取配置信息，确保变量正确设置
    get info $1
    # IS_COLOR=$(shuf -i 41-45 -n1)
    IS_COLOR=44
    case $NET in
    tcp | kcp | quic)
        IS_CAN_CHANGE=(0 1 5 7)
        IS_INFO_SHOW=(0 1 2 3 4 5)
        IS_VMESS_URL=$(jq -c '{v:2,ps:'\"${NET}-$IS_ADDR\"',add:'\"$IS_ADDR\"',port:'\"$PORT\"',id:'\"$UUID\"',aid:"0",net:'\"$NET\"',type:'\"$HEADER_TYPE\"',path:'\"$KCP_SEED\"'}' <<<{})
        IS_URL=vmess://$(echo -n $IS_VMESS_URL | base64 -w 0)
        IS_TMP_PORT=$PORT
        [[ $IS_DYNAMIC_PORT ]] && {
            IS_CAN_CHANGE+=(12)
            IS_TMP_PORT="$PORT & 动态端口: $IS_DYNAMIC_PORT_RANGE"
        }
        [[ $KCP_SEED ]] && {
            IS_INFO_SHOW+=(9)
            IS_CAN_CHANGE+=(14)
        }
        IS_INFO_STR=($IS_PROTOCOL $IS_ADDR "$IS_TMP_PORT" $UUID $NET $HEADER_TYPE $KCP_SEED)
        ;;
    ss)
        IS_CAN_CHANGE=(0 1 4 6)
        IS_INFO_SHOW=(0 1 2 10 11)
        IS_URL="ss://$(echo -n ${SS_METHOD}:${SS_PASSWORD} | base64 -w 0)@${IS_ADDR}:${PORT}#$NET-${IS_ADDR}"
        IS_INFO_STR=($IS_PROTOCOL $IS_ADDR $PORT $SS_PASSWORD $SS_METHOD)
        ;;
    ws | h2 | grpc)
        IS_COLOR=45
        IS_CAN_CHANGE=(0 1 2 3 5)
        IS_INFO_SHOW=(0 1 2 3 4 6 7 8)
        IS_URL_path=path
        IS_DISPLAY_PATH=$URL_PATH
        [[ $NET == 'grpc' ]] && {
            IS_DISPLAY_PATH=$(sed 's#/##g' <<<$URL_PATH)
            IS_URL_path=serviceName
        }
        [[ $IS_PROTOCOL == 'vmess' ]] && {
            IS_VMESS_URL=$(jq -c '{v:2,ps:'\"$NET-$HOST\"',add:'\"$IS_ADDR\"',port:'\"$IS_HTTPS_PORT\"',id:'\"$UUID\"',aid:"0",net:'\"$NET\"',host:'\"$HOST\"',path:'\"$URL_PATH\"',tls:'\"tls\"'}' <<<{})
            IS_URL=vmess://$(echo -n $IS_VMESS_URL | base64 -w 0)
        } || {
            [[ $IS_TROJAN ]] && {
                UUID=$TROJAN_PASSWORD
                IS_CAN_CHANGE=(0 1 2 3 4)
                IS_INFO_SHOW=(0 1 2 10 4 6 7 8)
            }
            IS_URL="$IS_PROTOCOL://$UUID@$HOST:$IS_HTTPS_PORT?encryption=none&security=tls&type=$NET&host=$HOST&${IS_URL_path}=$(sed 's#/#%2F#g' <<<$IS_DISPLAY_PATH)#$NET-$HOST"
        }
        [[ $IS_CADDY || $IS_NGINX ]] && IS_CAN_CHANGE+=(13)
        IS_INFO_STR=($IS_PROTOCOL $IS_ADDR $IS_HTTPS_PORT $UUID $NET $HOST $IS_DISPLAY_PATH 'tls')
        ;;
    reality)
        IS_COLOR=41
        IS_CAN_CHANGE=(0 1 5 10 11)
        IS_INFO_SHOW=(0 1 2 3 15 8 16 17 18)
        IS_INFO_STR=($IS_PROTOCOL $IS_ADDR $PORT $UUID xtls-rprx-vision reality $IS_SERVERNAME "ios" $IS_PUBLIC_KEY)
        IS_URL="$IS_PROTOCOL://$UUID@$IS_ADDR:$PORT?encryption=none&security=reality&flow=xtls-rprx-vision&type=tcp&sni=$IS_SERVERNAME&pbk=$IS_PUBLIC_KEY&fp=ios#$NET-$IS_ADDR"
        ;;
    door)
        IS_CAN_CHANGE=(0 1 8 9)
        IS_INFO_SHOW=(0 1 2 13 14)
        IS_INFO_STR=($IS_PROTOCOL $IS_ADDR $PORT $DOOR_ADDR $DOOR_PORT)
        ;;
    socks)
        IS_CAN_CHANGE=(0 1 15 4)
        IS_INFO_SHOW=(0 1 2 19 10)
        IS_INFO_STR=($IS_PROTOCOL $IS_ADDR $PORT $IS_SOCKS_USER $IS_SOCKS_PASS)
        IS_URL="socks://$(echo -n ${IS_SOCKS_USER}:${IS_SOCKS_PASS} | base64 -w 0)@${IS_ADDR}:${PORT}#$NET-${IS_ADDR}"
        ;;
    http)
        IS_CAN_CHANGE=(0 1)
        IS_INFO_SHOW=(0 1 2)
        IS_INFO_STR=($IS_PROTOCOL 127.0.0.1 $PORT)
        ;;
    esac
    [[ $IS_DONT_SHOW_INFO || $IS_GEN || $IS_DONT_AUTO_EXIT ]] && return # dont show info
    msg "-------------- $IS_CONFIG_NAME -------------"
    for ((i = 0; i < ${#IS_INFO_SHOW[@]}; i++)); do
        A=${INFO_LIST[${IS_INFO_SHOW[$i]}]}
        if [[ ${#A} -eq 11 || ${#A} -ge 13 ]]; then
            TT='\t'
        else
            TT='\t\t'
        fi
        msg "$A $TT= \e[${IS_COLOR}m${IS_INFO_STR[$i]}\e[0m"
    done
    if [[ $IS_NEW_INSTALL ]]; then
        warn "首次安装请查看脚本帮助文档: $(msg_ul https://wangyan-good.github.io/v2ray/$IS_CORE-script/)"
    fi
    if [[ $IS_URL ]]; then
        msg "------------- ${INFO_LIST[12]} -------------"
        msg "\e[4;${IS_COLOR}m${IS_URL}\e[0m"
    fi
    if [[ $IS_NO_AUTO_TLS ]]; then
        IS_TMP_PATH=$URL_PATH
        [[ $NET == 'grpc' ]] && IS_TMP_PATH="/$URL_PATH/*"
        msg "------------- no-auto-tls INFO -------------"
        msg "端口(port): $PORT"
        msg "路径(path): $IS_TMP_PATH"
        msg "\e[41m帮助(help)\e[0m: $(msg_ul https://wangyan-good.github.io/v2ray/no-auto-tls/)"
    fi
    footer_msg
}

# footer msg
footer_msg() {
    [[ $IS_CORE_stop && ! $IS_NEW_JSON ]] && warn "$IS_CORE_name 当前处于停止状态."
    [[ $IS_CADDY_stop && $HOST ]] && warn "Caddy 当前处于停止状态."
    [[ $IS_NGINX_stop && $HOST ]] && warn "Nginx 当前处于停止状态."
    msg "------------- END -------------"
    msg "文档(doc): $(msg_ul https://wangyan-good.github.io/v2ray/$IS_CORE-script/)"
}

# URL or qrcode
url_qr() {
    IS_DONT_SHOW_INFO=1
    info $2
    if [[ $IS_URL ]]; then
        [[ $1 == 'url' ]] && {
            msg "\n------------- $IS_CONFIG_NAME & URL 链接 -------------"
            msg "\n\e[${IS_COLOR}m${IS_URL}\e[0m\n"
            footer_msg
        } || {
            LINK="https://WangYan-Good.github.io/tools/qr.html#${IS_URL}"
            msg "\n------------- $IS_CONFIG_NAME & QR code 二维码 -------------"
            msg
            if [[ $(type -P qrencode) ]]; then
                qrencode -t ANSI "${IS_URL}"
            else
                msg "请安装 qrencode: $(_green "$CMD update -y; $CMD install qrencode -y")"
            fi
            msg
            msg "如果无法正常显示或识别, 请使用下面的链接来生成二维码:"
            msg "\n\e[4;${IS_COLOR}m${LINK}\e[0m\n"
            footer_msg
        }
    else
        [[ $1 == 'url' ]] && {
            err "($IS_CONFIG_NAME) 无法生成 URL 链接."
        } || {
            err "($IS_CONFIG_NAME) 无法生成 QR code 二维码."
        }
    fi
}

# update core, sh, caddy
update() {
    case $1 in
    1 | core | $is_core)
        IS_UPDATE_NAME=core
        IS_SHOW_NAME=$IS_CORE_name
        IS_RUN_VER=v${is_core_ver##* }
        IS_UPDATE_REPO=$IS_CORE_repo
        ;;
    2 | sh)
        IS_UPDATE_NAME=sh
        IS_SHOW_NAME="$IS_CORE_name 脚本"
        IS_RUN_VER=$IS_SH_VER
        IS_UPDATE_REPO=$IS_SH_REPO
        ;;
    3 | caddy)
        [[ ! $IS_CADDY ]] && err "不支持更新 Caddy."
        IS_UPDATE_NAME=caddy
        IS_SHOW_NAME="Caddy"
        IS_RUN_VER=$IS_CADDY_ver
        IS_UPDATE_REPO=$IS_CADDY_repo
        ;;
    4 | nginx)
        [[ ! $IS_NGINX ]] && err "不支持更新 Nginx."
        IS_UPDATE_NAME=nginx
        IS_SHOW_NAME="Nginx"
        IS_RUN_VER=$IS_NGINX_ver
        IS_UPDATE_REPO=$IS_NGINX_repo
        ;;
    *)
        err "无法识别 ($1), 请使用: $IS_CORE update [core | sh | caddy | nginx] [ver]"
        ;;
    esac
    [[ $2 ]] && IS_NEW_VER=v${2#v}
    [[ $IS_RUN_VER == $IS_NEW_VER ]] && {
        msg "\n自定义版本和当前 $IS_SHOW_NAME 版本一样, 无需更新.\n"
        exit
    }
    load download.sh
    if [[ $IS_NEW_VER ]]; then
        msg "\n使用自定义版本更新 $IS_SHOW_NAME: $(_green $IS_NEW_VER)\n"
    else
        get_latest_version $IS_UPDATE_NAME
        [[ $IS_RUN_VER == $latest_ver ]] && {
            msg "\n$IS_SHOW_NAME 当前已经是最新版本了.\n"
            exit
        }
        msg "\n发现 $IS_SHOW_NAME 新版本: $(_green $latest_ver)\n"
        IS_NEW_VER=$latest_ver
    fi
    download $IS_UPDATE_NAME $IS_NEW_VER
    msg "更新成功, 当前 $IS_SHOW_NAME 版本: $(_green $IS_NEW_VER)\n"
    msg "$(_green 请查看更新说明: https://github.com/$IS_UPDATE_REPO/releases/tag/$IS_NEW_VER)\n"
    [[ $IS_UPDATE_NAME == 'core' ]] && $IS_CORE restart
    [[ $IS_UPDATE_NAME == 'caddy' ]] && manage restart $IS_UPDATE_NAME &
}

# main menu; if no prefer args.
is_main_menu() {
    msg "\n------------- $IS_CORE_name script $IS_SH_VER by $AUTHOR -------------"
    msg "$IS_CORE_ver: $IS_CORE_status"
    IS_MAIN_START=1
    ask mainmenu
    case $REPLY in
    1)
        add
        ;;
    2)
        change
        ;;
    3)
        info
        ;;
    4)
        del
        ;;
    5)
        ask list IS_DO_MANAGE "启动 停止 重启"
        manage $REPLY &
        msg "\n管理状态执行: $(_green $IS_DO_MANAGE)\n"
        ;;
    6)
        IS_TMP_LIST=("更新$IS_CORE_name" "更新脚本")
        [[ $IS_CADDY ]] && IS_TMP_LIST+=("更新Caddy")
        ask list IS_DO_UPDATE null "\n请选择更新:\n"
        update $REPLY
        ;;
    7)
        uninstall
        ;;
    8)
        msg
        load help.sh
        show_help
        ;;
    9)
        ask list IS_DO_OTHER "启用BBR 查看日志 查看错误日志 测试运行 重装脚本 设置DNS"
        case $REPLY in
        1)
            load bbr.sh
            _try_enable_bbr
            ;;
        2)
            get log
            ;;
        3)
            get logerr
            ;;
        4)
            get test-run
            ;;
        5)
            get reinstall
            ;;
        6)
            load dns.sh
            dns_set
            ;;
        esac
        ;;
    10)
        load help.sh
        about
        ;;
    esac
}

# check prefer args, if not exist prefer args and show main menu
main() {
    case $1 in
    a | add | gen | no-auto-tls)
        [[ $1 == 'gen' ]] && IS_GEN=1
        [[ $1 == 'no-auto-tls' ]] && IS_NO_AUTO_TLS=1
        add ${@:2}
        ;;
    api | bin | convert | tls | run | uuid)
        [[ $IS_CORE_VER_LT_5 ]] && {
            warn "$IS_CORE_VER 版本不支持使用命令. 请升级内核版本: $IS_CORE UPDATE CORE"
            return
        }
        IS_RUN_COMMAND=$1
        if [[ $1 == 'bin' ]]; then
            $IS_CORE_BIN ${@:2}
        else
            # [[ $IS_RUN_COMMAND == 'pbk' ]] && IS_RUN_COMMAND=x25519
            $IS_CORE_BIN $IS_RUN_COMMAND ${@:2}
        fi
        ;;
    bbr)
        load bbr.sh
        _try_enable_bbr
        ;;
    c | config | change)
        change ${@:2}
        ;;
    client | genc)
        [[ $1 == 'client' ]] && IS_FULL_CLIENT=1
        create client $2
        ;;
    d | del | rm)
        del $2
        ;;
    dd | ddel | fix | fix-all)
        case $1 in
        fix)
            [[ $2 ]] && {
                change $2 full
            } || {
                IS_CHANGE_ID=full && change
            }
            return
            ;;
        fix-all)
            IS_DONT_AUTO_EXIT=1
            msg
            for v in $(ls $IS_CONF_DIR | grep .json$ | sed '/dynamic-port-.*-link/d'); do
                msg "fix: $V"
                change $V full
            done
            _green "\nfix 完成.\n"
            ;;
        *)
            IS_DONT_AUTO_EXIT=1
            [[ ! $2 ]] && {
                err "无法找到需要删除的参数"
            } || {
                for v in ${@:2}; do
                    del $V
                done
            }
            ;;
        esac
        IS_DONT_AUTO_EXIT=
        [[ $IS_API_FAIL ]] && manage restart &
        [[ $IS_DEL_HOST ]] && {
            [[ $IS_CADDY ]] && manage restart caddy &
            [[ $IS_NGINX ]] && manage restart nginx &
        }
        ;;
    dns)
        load dns.sh
        dns_set ${@:2}
        ;;
    debug)
        get info $2
        warn "如果需要复制; 请把 *uuid, *password, *host, *key 的值改写, 以避免泄露."
        ;;
    fix-config.json)
        create config.json
        ;;
    fix-caddyfile)
        if [[ $IS_CADDY ]]; then
            load caddy.sh
            caddy_config new
            manage restart caddy &
            _green "\nfix 完成.\n"
        else
            err "无法执行此操作"
        fi
        ;;
    fix-nginxfile)
        if [[ $IS_NGINX ]]; then
            load nginx.sh
            nginx_config new
            nginx_reload
            _green "\nfix 完成.\n"
        else
            err "无法执行此操作"
        fi
        ;;
    i | info)
        info $2
        ;;
    ip)
        get_ip
        msg $IP
        ;;
    log | logerr | errlog)
        load log.sh
        log_set $@
        ;;
    url | qr)
        url_qr $@
        ;;
    un | uninstall)
        uninstall
        ;;
    u | up | update | U | update.sh)
        IS_UPDATE_NAME=$2
        IS_UPDATE_VER=$3
        [[ ! $IS_UPDATE_NAME ]] && IS_UPDATE_NAME=core
        [[ $1 == 'U' || $1 == 'update.sh' ]] && {
            IS_UPDATE_NAME=sh
            IS_UPDATE_VER=
        }
        if [[ $2 == 'dat' ]]; then
            load download.sh
            download dat
            msg "$(_green 更新 geoip.dat geosite.dat 成功.)\n"
            manage restart &
        else
            update $IS_UPDATE_NAME $IS_UPDATE_VER
        fi
        ;;
    ssss | ss2022)
        get $@
        ;;
    s | status)
        msg "\n$IS_CORE_VER: $IS_CORE_STATUS\n"
        [[ $IS_CADDY ]] && msg "Caddy $IS_CADDY_VER: $IS_CADDY_STATUS\n"
        [[ $IS_NGINX ]] && msg "Nginx $IS_NGINX_VER: $IS_NGINX_STATUS\n"
        ;;
    start | stop | r | restart)
        [[ $2 && $2 != 'caddy' ]] && err "无法识别 ($2), 请使用: $IS_CORE $1 [caddy]"
        manage $1 $2 &
        ;;
    t | test)
        get test-run
        ;;
    reinstall)
        get $1
        ;;
    get-port)
        get_port
        msg $TMP_PORT
        ;;
    main)
        is_main_menu
        ;;
    v | ver | version)
        [[ $IS_CADDY_VER ]] && IS_CADDY_VER="/ $(_blue Caddy $IS_CADDY_VER)"
        msg "\n$(_green $IS_CORE_VER) / $(_cyan $IS_CORE_NAME script $IS_SH_VER) $IS_CADDY_VER\n"
        ;;
    xapi)
        api ${@:2}
        ;;
    h | help | --help)
        load help.sh
        show_help ${@:2}
        ;;
    *)
        IS_TRY_CHANGE=1
        change test $1
        if [[ $IS_CHANGE_ID ]]; then
            unset IS_TRY_CHANGE
            [[ $2 ]] && {
                change $2 $1 ${@:3}
            } || {
                change
            }
        else
            err "无法识别 ($1), 获取帮助请使用: $IS_CORE help"
        fi
        ;;
    esac
}
