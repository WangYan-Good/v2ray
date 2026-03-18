#!/bin/bash

get_latest_version() {
    case $1 in
    core)
        NAME=$IS_CORE_NAME
        URL="https://api.github.com/repos/${IS_CORE_REPO}/releases/latest?v=$RANDOM"
        ;;
    sh)
        NAME="$IS_CORE_NAME 脚本"
        URL="https://api.github.com/repos/$IS_SH_REPO/releases/latest?v=$RANDOM"
        ;;
    caddy)
        NAME="Caddy"
        URL="https://api.github.com/repos/$IS_CADDY_REPO/releases/latest?v=$RANDOM"
        ;;
    nginx)
        # Nginx 使用包管理器安装，不需要获取版本
        LATEST_VER=system
        return
        ;;
    esac
    LATEST_VER=$(_wget -qO- $URL | grep tag_name | grep -E -o 'v([0-9.]+)')
    [[ ! $LATEST_VER ]] && {
        err "获取 ${NAME} 最新版本失败."
    }
    unset NAME URL
}
download() {
    LATEST_VER=$2
    [[ ! $LATEST_VER && $1 != 'dat' ]] && get_latest_version $1
    # tmp dir
    TMPDIR=$(mktemp -u)
    [[ ! $TMPDIR ]] && {
        TMPDIR=/tmp/tmp-$RANDOM
    }
    mkdir -p $TMPDIR
    case $1 in
    core)
        NAME=$IS_CORE_NAME
        TMPFILE=$TMPDIR/$IS_CORE.zip
        LINK="https://github.com/${IS_CORE_REPO}/releases/download/${LATEST_VER}/${IS_CORE}-linux-${IS_CORE_ARCH}.zip"
        download_file
        unzip -qo $TMPFILE -d $IS_CORE_DIR/bin
        chmod +x $IS_CORE_BIN
        ;;
    sh)
        NAME="$IS_CORE_NAME 脚本"
        TMPFILE=$TMPDIR/sh.zip
        LINK="https://github.com/${IS_SH_REPO}/releases/download/${LATEST_VER}/code.zip"
        download_file
        unzip -qo $TMPFILE -d $IS_SH_DIR
        chmod +x $IS_SH_BIN
        ;;
    dat)
        NAME="geoip.dat"
        TMPFILE=$TMPDIR/geoip.dat
        LINK="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
        download_file
        NAME="geosite.dat"
        TMPFILE=$TMPDIR/geosite.dat
        LINK="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
        download_file
        cp -f $TMPDIR/*.dat $IS_CORE_DIR/bin/
        ;;
    caddy)
        NAME="Caddy"
        # 检测是否已安装 Caddy
        if [[ -f $IS_CADDY_BIN ]]; then
            msg warn "检测到 Caddy 已安装，使用现有 Caddy"
            rm -rf $TMPDIR
        else
            TMPFILE=$TMPDIR/caddy.tar.gz
            LINK="https://github.com/${IS_CADDY_REPO}/releases/download/${LATEST_VER}/caddy_${LATEST_VER:1}_linux_${CADDY_ARCH}.tar.gz"
            download_file
            [[ ! $(type -P tar) ]] && {
                rm -rf $TMPDIR
                err "请安装 tar"
            }
            tar zxf $TMPFILE -C $TMPDIR
            cp -f $TMPDIR/caddy $IS_CADDY_BIN
            chmod +x $IS_CADDY_BIN
        fi
        ;;
    nginx)
        NAME="Nginx + Certbot"
        msg warn "配置 Nginx + Certbot..."
        
        # 检测是否已安装 Nginx
        if [[ $(type -P nginx) ]]; then
            msg warn "检测到 Nginx 已安装，使用现有 Nginx"
        else
            # 安装 Nginx
            if [[ $CMD =~ apt-get ]]; then
                $CMD update -y &>/dev/null
                $CMD install nginx -y &>/dev/null
            else
                $CMD install epel-release -y &>/dev/null
                $CMD update -y &>/dev/null
                $CMD install nginx -y &>/dev/null
            fi
            if [[ ! $(type -P nginx) ]]; then
                rm -rf $TMPDIR
                err "Nginx 安装失败"
            fi
        fi
        
        # 检测是否已安装 Certbot
        if [[ $(type -P certbot) ]]; then
            msg warn "检测到 Certbot 已安装，使用现有 Certbot"
        else
            # 安装 Certbot
            if [[ $CMD =~ apt-get ]]; then
                $CMD install certbot python3-certbot-nginx -y &>/dev/null
            else
                $CMD install certbot python3-certbot-nginx -y &>/dev/null
            fi
            if [[ ! $(type -P certbot) ]]; then
                rm -rf $TMPDIR
                err "Certbot 安装失败"
            fi
        fi
        
        # 备份现有 Nginx 配置（如果有）
        if [[ -f $IS_NGINXFILE && ! -f ${IS_NGINXFILE}.bak ]]; then
            cp -f $IS_NGINXFILE ${IS_NGINXFILE}.bak
            msg warn "已备份现有 nginx.conf 到 ${IS_NGINXFILE}.bak"
        fi
        
        # 设置开机自启
        systemctl enable nginx &>/dev/null
        systemctl daemon-reload
        
        rm -rf $TMPDIR
        ;;
    esac
    rm -rf $TMPDIR
    unset LATEST_VER
}
download_file() {
    if ! _wget -t 5 -c $LINK -O $TMPFILE; then
        rm -rf $TMPDIR
        err "\n下载 ${NAME} 失败.\n"
    fi
}
