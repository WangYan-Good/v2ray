#!/bin/bash

get_latest_version() {
    case $1 in
    core)
        name=$is_core_name
        url="https://api.github.com/repos/${is_core_repo}/releases/latest?v=$RANDOM"
        ;;
    sh)
        name="$is_core_name 脚本"
        url="https://api.github.com/repos/$is_sh_repo/releases/latest?v=$RANDOM"
        ;;
    caddy)
        name="Caddy"
        url="https://api.github.com/repos/$is_caddy_repo/releases/latest?v=$RANDOM"
        ;;
    nginx)
        # Nginx 使用包管理器安装，不需要获取版本
        latest_ver=system
        return
        ;;
    esac
    latest_ver=$(_wget -qO- $url | grep tag_name | grep -E -o 'v([0-9.]+)')
    [[ ! $latest_ver ]] && {
        err "获取 ${name} 最新版本失败."
    }
    unset name url
}
download() {
    latest_ver=$2
    [[ ! $latest_ver && $1 != 'dat' ]] && get_latest_version $1
    # tmp dir
    tmpdir=$(mktemp -u)
    [[ ! $tmpdir ]] && {
        tmpdir=/tmp/tmp-$RANDOM
    }
    mkdir -p $tmpdir
    case $1 in
    core)
        name=$is_core_name
        tmpfile=$tmpdir/$is_core.zip
        link="https://github.com/${is_core_repo}/releases/download/${latest_ver}/${is_core}-linux-${is_core_arch}.zip"
        download_file
        unzip -qo $tmpfile -d $is_core_dir/bin
        chmod +x $is_core_bin
        ;;
    sh)
        name="$is_core_name 脚本"
        tmpfile=$tmpdir/sh.zip
        link="https://github.com/${is_sh_repo}/releases/download/${latest_ver}/code.zip"
        download_file
        unzip -qo $tmpfile -d $is_sh_dir
        chmod +x $is_sh_bin
        ;;
    dat)
        name="geoip.dat"
        tmpfile=$tmpdir/geoip.dat
        link="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
        download_file
        name="geosite.dat"
        tmpfile=$tmpdir/geosite.dat
        link="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
        download_file
        cp -f $tmpdir/*.dat $is_core_dir/bin/
        ;;
    caddy)
        name="Caddy"
        # 检测是否已安装 Caddy
        if [[ -f $is_caddy_bin ]]; then
            msg warn "检测到 Caddy 已安装，使用现有 Caddy"
            rm -rf $tmpdir
        else
            tmpfile=$tmpdir/caddy.tar.gz
            link="https://github.com/${is_caddy_repo}/releases/download/${latest_ver}/caddy_${latest_ver:1}_linux_${caddy_arch}.tar.gz"
            download_file
            [[ ! $(type -P tar) ]] && {
                rm -rf $tmpdir
                err "请安装 tar"
            }
            tar zxf $tmpfile -C $tmpdir
            cp -f $tmpdir/caddy $is_caddy_bin
            chmod +x $is_caddy_bin
        fi
        ;;
    nginx)
        name="Nginx + Certbot"
        msg warn "配置 Nginx + Certbot..."
        
        # 检测是否已安装 Nginx
        if [[ $(type -P nginx) ]]; then
            msg warn "检测到 Nginx 已安装，使用现有 Nginx"
        else
            # 安装 Nginx
            if [[ $cmd =~ apt-get ]]; then
                $cmd update -y &>/dev/null
                $cmd install nginx -y &>/dev/null
            else
                $cmd install epel-release -y &>/dev/null
                $cmd update -y &>/dev/null
                $cmd install nginx -y &>/dev/null
            fi
            if [[ ! $(type -P nginx) ]]; then
                rm -rf $tmpdir
                err "Nginx 安装失败"
            fi
        fi
        
        # 检测是否已安装 Certbot
        if [[ $(type -P certbot) ]]; then
            msg warn "检测到 Certbot 已安装，使用现有 Certbot"
        else
            # 安装 Certbot
            if [[ $cmd =~ apt-get ]]; then
                $cmd install certbot python3-certbot-nginx -y &>/dev/null
            else
                $cmd install certbot python3-certbot-nginx -y &>/dev/null
            fi
            if [[ ! $(type -P certbot) ]]; then
                rm -rf $tmpdir
                err "Certbot 安装失败"
            fi
        fi
        
        # 备份现有 Nginx 配置（如果有）
        if [[ -f $is_nginxfile && ! -f ${is_nginxfile}.bak ]]; then
            cp -f $is_nginxfile ${is_nginxfile}.bak
            msg warn "已备份现有 nginx.conf 到 ${is_nginxfile}.bak"
        fi
        
        # 设置开机自启
        systemctl enable nginx &>/dev/null
        systemctl daemon-reload
        
        rm -rf $tmpdir
        ;;
    esac
    rm -rf $tmpdir
    unset latest_ver
}
download_file() {
    if ! _wget -t 5 -c $link -O $tmpfile; then
        rm -rf $tmpdir
        err "\n下载 ${name} 失败.\n"
    fi
}
