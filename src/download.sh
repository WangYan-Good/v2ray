#!/bin/bash

##
## 校验 SHA256 完整性
## 用法: verify_sha256 <文件路径> <校验和>
## 返回: 0 = 通过, 1 = 失败
##
verify_sha256() {
    local file="$1"
    local expected_hash="$2"
    local actual_hash

    actual_hash=$(sha256sum "$file" | awk '{print $1}')

    if [[ "$actual_hash" == "$expected_hash" ]]; then
        return 0
    else
        return 1
    fi
}

##
## 获取 Xray-core 的 SHA256 校验和 (从 .dgst 文件)
## 用法: get_xray_checksum <下载链接> <版本> <架构>
## 输出: SHA256 字符串 或 空
##
get_xray_checksum() {
    local dl_link="$1"
    local ver="$2"
    local arch="$3"
    local dgst_url="${dl_link}.dgst"
    local tmp_dgst=$(mktemp)

    if _wget -t 3 -q -c "$dgst_url" -O "$tmp_dgst" 2>/dev/null; then
        grep 'SHA2-256=' "$tmp_dgst" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]'
    fi
    rm -f "$tmp_dgst"
}

##
## 获取 Caddy 的 SHA256 校验和 (从 checksums.txt 文件)
## checksums.txt 格式: 第一行=hash, 第二行=文件名 (两行一组)
## 用法: get_caddy_checksum <版本> <架构>
## 输出: SHA256 字符串 或 空
##
get_caddy_checksum() {
    local ver="$1"
    local arch="$2"
    local base_url="https://github.com/${is_caddy_repo}/releases/download/${ver}"
    local checksum_url="${base_url}/caddy_${ver#v}_checksums.txt"
    local tmp_checksum=$(mktemp)

    if _wget -t 3 -q -c "$checksum_url" -O "$tmp_checksum" 2>/dev/null; then
        # 两行一组: 第一行=hash, 第二行=文件名
        grep -A1 "caddy_${ver#v}_linux_${arch}.tar.gz" "$tmp_checksum" 2>/dev/null | head -1
    fi
    rm -f "$tmp_checksum"
}

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

        ## SHA256 校验 (Xray-core)
        expected_sha=$(get_xray_checksum "$link" "$latest_ver" "$is_core_arch")
        if [[ -n "$expected_sha" ]]; then
            if verify_sha256 "$tmpfile" "$expected_sha"; then
                msg ok "${name} 文件完整性验证通过"
            else
                rm -rf $tmpdir
                err "${name} 文件校验和不匹配. 请检查下载链接: $link"
            fi
        else
            msg warn "无法获取 ${name} 校验和，跳过验证"
        fi

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

            ## SHA256 校验 (Caddy)
            expected_sha=$(get_caddy_checksum "$latest_ver" "$caddy_arch")
            if [[ -n "$expected_sha" ]]; then
                if verify_sha256 "$tmpfile" "$expected_sha"; then
                    msg ok "${name} 文件完整性验证通过"
                else
                    rm -rf $tmpdir
                    err "${name} 文件校验和不匹配. 请检查下载链接: $link"
                fi
            else
                msg warn "无法获取 ${name} 校验和，跳过验证"
            fi

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
        if [[ -f $is_nginx_file && ! -f ${is_nginx_file}.bak ]]; then
            cp -f $is_nginx_file ${is_nginx_file}.bak
            msg warn "已备份现有 nginx.conf 到 ${is_nginx_file}.bak"
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
