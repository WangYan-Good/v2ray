#!/bin/bash

AUTHOR=WangYan-Good
# github=https://github.com/WangYan-Good/v2ray

# bash fonts colors
RED='\e[31m'
YELLOW='\e[33m'
GRAY='\e[90m'
GREEN='\e[92m'
BLUE='\e[94m'
MAGENTA='\e[95m'
CYAN='\e[96m'
NONE='\e[0m'

_red() { echo -e ${RED}$@${NONE}; }
_blue() { echo -e ${BLUE}$@${NONE}; }
_cyan() { echo -e ${CYAN}$@${NONE}; }
_green() { echo -e ${GREEN}$@${NONE}; }
_yellow() { echo -e ${YELLOW}$@${NONE}; }
_magenta() { echo -e ${MAGENTA}$@${NONE}; }
_red_bg() { echo -e "\e[41m$@${NONE}"; }

_rm() {
    rm -rf "$@"
}
_cp() {
    cp -rf "$@"
}
_sed() {
    sed -i "$@"
}
_mkdir() {
    mkdir -p "$@"
}

IS_ERR=$(_red_bg 错误!)
IS_WARN=$(_red_bg 警告!)

err() {
    echo -e "\n$IS_ERR $@\n"
    [[ $IS_DONT_AUTO_EXIT ]] && return
    exit 1
}

warn() {
    echo -e "\n$IS_WARN $@\n"
}

# load bash script.
load() {
    . $IS_SH_DIR/src/$1
}

# wget add --no-check-certificate
_wget() {
    # [[ $PROXY ]] && export HTTPS_PROXY=$PROXY
    wget --no-check-certificate "$@"
}

# yum or apt-get
CMD=$(type -P apt-get || type -P yum)

# x64
case $(arch) in
amd64 | x86_64)
    IS_CORE_ARCH="64"
    CADDY_ARCH="amd64"
    ;;
*aarch64* | *armv8*)
    IS_CORE_ARCH="arm64-v8a"
    CADDY_ARCH="arm64"
    ;;
*)
    err "此脚本仅支持 64 位系统..."
    ;;
esac

IS_CORE=v2ray
IS_CORE_NAME=V2Ray
IS_CORE_DIR=/etc/$IS_CORE
IS_CORE_BIN=$IS_CORE_DIR/bin/$IS_CORE
IS_CORE_REPO=v2fly/$IS_CORE-core
IS_CONF_DIR=$IS_CORE_DIR/conf
IS_LOG_DIR=/var/log/$IS_CORE
IS_SH_BIN=/usr/local/bin/$IS_CORE
IS_SH_DIR=$IS_CORE_DIR/sh
IS_SH_REPO=$AUTHOR/$IS_CORE
IS_PKG="wget unzip jq qrencode"
IS_CONFIG_JSON=$IS_CORE_DIR/config.json
IS_CADDY_BIN=/usr/local/bin/caddy
IS_CADDY_DIR=/etc/caddy
IS_CADDY_REPO=caddyserver/caddy
IS_CADDYFILE=$IS_CADDY_DIR/Caddyfile
IS_CADDY_CONF=$IS_CADDY_DIR/$AUTHOR
IS_CADDY_SERVICE=$(systemctl list-units --full -all | grep caddy.service)
IS_NGINX_BIN=/usr/sbin/nginx
IS_NGINX_DIR=/etc/nginx
IS_NGINX_REPO=nginx/nginx
IS_NGINXFILE=$IS_NGINX_DIR/nginx.conf
IS_NGINX_CONF=$IS_NGINX_DIR/v2ray
IS_NGINX_SERVICE=$(systemctl list-units --full -all | grep nginx.service)
IS_HTTP_PORT=80
IS_HTTPS_PORT=443

# core ver
IS_CORE_VER=$($IS_CORE_BIN version | head -n1 | cut -d " " -f1-2)

if [[ $(grep -o ^[0-9] <<<${IS_CORE_VER#* }) -lt 5 ]]; then
    # core version less than 5, e.g, v4.45.2
    IS_CORE_VER_LT_5=1
    if [[ $(grep 'run -config' /lib/systemd/system/v2ray.service) ]]; then
        sed -i 's/run //' /lib/systemd/system/v2ray.service
        systemctl daemon-reload
    fi
else
    IS_WITH_RUN_ARG=run
    if [[ ! $(grep 'run -config' /lib/systemd/system/v2ray.service) ]]; then
        sed -i 's/-config/run -config/' /lib/systemd/system/v2ray.service
        systemctl daemon-reload
    fi
fi

if [[ $(pgrep -f $IS_CORE_BIN) ]]; then
    IS_CORE_STATUS=$(_green running)
else
    IS_CORE_STATUS=$(_red_bg stopped)
    IS_CORE_STOP=1
fi
if [[ -f $IS_CADDY_BIN && -d $IS_CADDY_DIR && $IS_CADDY_SERVICE ]]; then
    IS_CADDY=1
    # fix caddy run; ver >= 2.8.2
    [[ ! $(grep '\-\-adapter caddyfile' /lib/systemd/system/caddy.service) ]] && {
        load systemd.sh
        install_service caddy
        systemctl restart caddy &
    }
    IS_CADDY_VER=$($IS_CADDY_BIN version | head -n1 | cut -d " " -f1)
    IS_TMP_HTTP_PORT=$(grep -E '^ {2,}http_port|^http_port' $IS_CADDYFILE | grep -E -o [0-9]+)
    IS_TMP_HTTPS_PORT=$(grep -E '^ {2,}https_port|^https_port' $IS_CADDYFILE | grep -E -o [0-9]+)
    [[ $IS_TMP_HTTP_PORT ]] && IS_HTTP_PORT=$IS_TMP_HTTP_PORT
    [[ $IS_TMP_HTTPS_PORT ]] && IS_HTTPS_PORT=$IS_TMP_HTTPS_PORT
    if [[ $(pgrep -f $IS_CADDY_BIN) ]]; then
        IS_CADDY_STATUS=$(_green running)
    else
        IS_CADDY_STATUS=$(_red_bg stopped)
        IS_CADDY_STOP=1
    fi
fi

# Nginx 状态检测
if [[ -f $IS_NGINX_BIN && -d $IS_NGINX_DIR && $IS_NGINX_SERVICE ]]; then
    IS_NGINX=1
    IS_NGINX_VER=$($IS_NGINX_BIN -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    IS_TMP_HTTP_PORT=$(grep -E 'listen.*\s80\s|listen\s80\s' $IS_NGINXFILE 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1)
    IS_TMP_HTTPS_PORT=$(grep -E 'listen.*\s443\s|listen\s443\s' $IS_NGINXFILE 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1)
    [[ $IS_TMP_HTTP_PORT ]] && IS_HTTP_PORT=$IS_TMP_HTTP_PORT
    [[ $IS_TMP_HTTPS_PORT ]] && IS_HTTPS_PORT=$IS_TMP_HTTPS_PORT
    if [[ $(pgrep -f $IS_NGINX_BIN) ]]; then
        IS_NGINX_STATUS=$(_green running)
    else
        IS_NGINX_STATUS=$(_red_bg stopped)
        IS_NGINX_STOP=1
    fi
fi

load core.sh
# old sh ver
IS_OLD_DIR=/etc/v2ray/old_backup
IS_OLD_CONF=/etc/v2ray/233blog_v2ray_backup.conf
if [[ -f $IS_OLD_CONF && -d $IS_OLD_DIR ]]; then
    load old.sh
fi
[[ ! $ARGS ]] && ARGS=main
main $ARGS
