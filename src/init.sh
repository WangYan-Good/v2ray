#!/bin/bash

author=WangYan-Good
# github=https://github.com/WangYan-Good/xray

##
## bash fonts colors
##
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

_red() { echo -e ${red}$@${none}; }
_blue() { echo -e ${blue}$@${none}; }
_cyan() { echo -e ${cyan}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }
_magenta() { echo -e ${magenta}$@${none}; }
_red_bg() { echo -e "\e[41m$@${none}"; }

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

##
## 错误码常量 (统一错误处理机制 T8)
##
ERR_DOWNLOAD=1
ERR_CHECKSUM=2
ERR_PERMISSION=3
ERR_ARCH=4
ERR_DEPENDENCY=5
ERR_CERT=6
ERR_CONFIG=7
ERR_SERVICE=8
ERR_PORT=9
ERR_UUID=10
ERR_JSON=11
ERR_NGINX=12
ERR_CADDY=13
ERR_PROTOCOL=14
ERR_API=15
ERR_UNKNOWN=99

##
## 统一错误输出函数
## 用法: error_out <错误码名称> <错误信息> [修复建议]
## 示例: error_out "CERT" "证书申请失败" "1. 检查域名 2. 检查防火墙"
## 输出: [ERR_CERT:6] 错误! 证书申请失败
##
error_out() {
    local code_name="$1"
    local msg="$2"
    local suggestion="${3:-请查看帮助文档: https://wangyan-good.github.io/xray/ 或运行 xray help}"
    local log_file="/var/log/xray/install.log"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    # 尝试获取数字错误码 (从 ERR_ 常量)
    local code_var="ERR_${code_name}"
    local code_num="${!code_var:-}"
    local display_code="${code_name}"
    if [[ -n "$code_num" ]]; then
        display_code="${code_name}:${code_num}"
    fi
    # 写入日志文件 (如果目录存在)
    if [[ -d "$(dirname "$log_file")" ]]; then
        echo "[${timestamp}] [ERR_${display_code}] ${msg}" >> "$log_file"
        echo "[${timestamp}] [SUGGESTION] ${suggestion}" >> "$log_file"
    fi
    echo -e "\n${red}[ERR_${display_code}] 错误! ${msg}${none}"
    echo -e "${yellow}建议: ${suggestion}${none}\n"
}

##
## 统一信息日志函数
## 用法: log_info <信息>
##
log_info() {
    local log_file="/var/log/xray/install.log"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    if [[ -d "$(dirname "$log_file")" ]]; then
        echo "[${timestamp}] [INFO] $*" >> "$log_file"
    fi
}

##
## 统一警告输出函数
## 用法: warn_out <警告信息>
##
warn_out() {
    local log_file="/var/log/xray/install.log"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    if [[ -d "$(dirname "$log_file")" ]]; then
        echo "[${timestamp}] [WARN] $*" >> "$log_file"
    fi
    echo -e "\n${yellow}[WARN] 警告! $@${none}\n"
}

is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)

##
## 旧 err() 函数 (向后兼容，逐步迁移到 error_out)
## 用法: err <错误信息>
## 注意: 新代码推荐使用 error_out <错误码> <错误信息> <修复建议>
##
err() {
    echo -e "\n$is_err $@\n"
    [[ $is_dont_auto_exit ]] && return
    exit 1
}

##
## 旧 warn() 函数 (向后兼容，逐步迁移到 warn_out)
##
warn() {
    echo -e "\n$is_warn $@\n"
}

##
## load bash script.
## 加载执行 /etc/xray/sh/src/ 下传参的第一个参数文件
##
load() {
    . $is_sh_dir/src/$1
}

##
## wget add --secure-protocol=TLSv1_2 (默认验证 SSL 证书)
##
_wget() {
    # [[ $proxy ]] && export https_proxy=$proxy
    wget --secure-protocol=TLSv1_2 "$@"
}

##
## yum or apt-get
##
cmd=$(type -P apt-get || type -P yum)

##
## x64
##
case $(arch) in
amd64 | x86_64)
    is_core_arch="64"
    caddy_arch="amd64"
    ;;
*aarch64* | *armv8*)
    is_core_arch="arm64-v8a"
    caddy_arch="arm64"
    ;;
*)
    err "此脚本仅支持 64 位系统..."
    ;;
esac

# Xray-core 变量定义
is_core=xray                            # is_core      = xray
is_core_name=Xray                       # is_core_name = Xray
is_core_dir=/etc/$is_core               # is_core_dir  = /etc/xray
is_core_bin=$is_core_dir/bin/$is_core   # is_core_bin  = /etc/xray/bin/xray
# Xray-core 支持 xhttp、REALITY 等新特性
is_core_repo=XTLS/Xray-core             # is_core_repo = XTLS/Xray-core
is_conf_dir=$is_core_dir/conf           # is_conf_dir  = /etc/xray/conf
is_log_dir=/var/log/$is_core            # is_log_dir   = /var/log/xray
is_sh_bin=/usr/local/bin/$is_core       # is_sh_bin    = /usr/local/bin/xray
is_sh_dir=$is_core_dir/sh               # is_sh_dir    = /etc/xray/sh
is_sh_repo=$author/$is_core             # is_sh_repo   = WangYan-Good/xray
is_pkg="wget unzip jq qrencode"
is_config_json=$is_core_dir/config.json # is_config_json = /etc/xray/config.json
is_sub_dir=$is_core_dir/sub             # is_sub_dir = /etc/xray/sub
is_mihomo_sub_file=$is_sub_dir/mihomo.yaml
is_sub_token_file=$is_sub_dir/token
is_caddy_bin=/usr/local/bin/caddy
is_caddy_dir=/etc/caddy
is_caddy_repo=caddyserver/caddy
is_caddy_file=$is_caddy_dir/Caddyfile
is_caddy_conf=$is_caddy_dir/$author
is_caddy_service=$(systemctl list-units --full -all | grep caddy.service)
is_nginx_bin=/usr/sbin/nginx
is_nginx_dir=/etc/nginx
is_nginx_repo=nginx/nginx
is_nginx_file=$is_nginx_dir/nginx.conf
is_nginx_conf=$is_nginx_dir/xray        # Xray Nginx 配置目录
is_nginx_service=$(systemctl list-units --full -all | grep nginx.service)
is_http_port=80
is_https_port=443

##
## core ver
##
is_core_ver=$($is_core_bin version | head -n1 | cut -d " " -f1-2)
is_core_major=${is_core_ver#* }
is_core_major=${is_core_major%%.*}

if [[ $is_core_major =~ ^[0-9]+$ && $is_core_major -lt 5 ]]; then
    # core version less than 5, e.g, v4.45.2
    is_core_ver_lt_5=1
    if [[ $EUID -eq 0 && -f /lib/systemd/system/$is_core.service && $(grep 'run -config' /lib/systemd/system/$is_core.service) ]]; then
        sed -i 's/run //' /lib/systemd/system/$is_core.service
        systemctl daemon-reload
    fi
else
    is_with_run_arg=run
    if [[ $EUID -eq 0 && -f /lib/systemd/system/$is_core.service && ! $(grep 'run -config' /lib/systemd/system/$is_core.service) ]]; then
        sed -i 's/-config/run -config/' /lib/systemd/system/$is_core.service
        systemctl daemon-reload
    fi
fi

if [[ $(pgrep -f $is_core_bin) ]]; then
    is_core_status=$(_green running)
else
    is_core_status=$(_red_bg stopped)
    is_core_stop=1
fi
if [[ -f $is_caddy_bin && -d $is_caddy_dir && $is_caddy_service ]]; then
    is_caddy=1
    # fix caddy run; ver >= 2.8.2
    [[ ! $(grep '\-\-adapter caddyfile' /lib/systemd/system/caddy.service) ]] && {
        load systemd.sh
        install_service caddy
        systemctl restart caddy &
    }
    is_caddy_ver=$($is_caddy_bin version | head -n1 | cut -d " " -f1)
    is_tmp_http_port=$(grep -E '^ {2,}http_port|^http_port' $is_caddy_file | grep -E -o [0-9]+)
    is_tmp_https_port=$(grep -E '^ {2,}https_port|^https_port' $is_caddy_file | grep -E -o [0-9]+)
    [[ $is_tmp_http_port ]] && is_http_port=$is_tmp_http_port
    [[ $is_tmp_https_port ]] && is_https_port=$is_tmp_https_port
    if [[ $(pgrep -f $is_caddy_bin) ]]; then
        is_caddy_status=$(_green running)
    else
        is_caddy_status=$(_red_bg stopped)
        is_caddy_stop=1
    fi
fi

##
## Nginx 状态检测
##
if [[ -f $is_nginx_bin && -d $is_nginx_dir && $is_nginx_service ]]; then
    is_nginx=1
    is_nginx_ver=$($is_nginx_bin -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    is_tmp_http_port=$(grep -E 'listen.*\s80\s|listen\s80\s' $is_nginx_file 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1)
    is_tmp_https_port=$(grep -E 'listen.*\s443\s|listen\s443\s' $is_nginx_file 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1)
    [[ $is_tmp_http_port ]] && is_http_port=$is_tmp_http_port
    [[ $is_tmp_https_port ]] && is_https_port=$is_tmp_https_port
    if [[ $(pgrep -f $is_nginx_bin) ]]; then
        is_nginx_status=$(_green running)
    else
        is_nginx_status=$(_red_bg stopped)
        is_nginx_stop=1
    fi
fi

load core.sh

##
## old sh ver (旧版本备份路径，用于从旧版本迁移)
##
is_old_dir=/etc/v2ray/old_backup
is_old_conf=/etc/v2ray/v2ray_backup.conf
if [[ -f $is_old_conf && -d $is_old_dir ]]; then
    load old.sh
fi
[[ ! $args ]] && args=main
main $args
