#!/bin/bash

author=WangYan-Good
# github=https://github.com/WangYan-Good/xray

# bash fonts colors
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'
_red() { echo -e "${red}$*${none}"; }
_blue() { echo -e "${blue}$*${none}"; }
_cyan() { echo -e "${cyan}$*${none}"; }
_green() { echo -e "${green}$*${none}"; }
_yellow() { echo -e "${yellow}$*${none}"; }
_magenta() { echo -e "${magenta}$*${none}"; }
_red_bg() { echo -e "\e[41m$*${none}"; }

is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)

##
## 错误码常量 (T8: 统一错误处理)
##
ERR_DOWNLOAD=1
ERR_CHECKSUM=2
ERR_PERMISSION=3
ERR_ARCH=4
ERR_DEPENDENCY=5
ERR_CERT=6
ERR_CONFIG=7
ERR_SERVICE=8

err() {
    echo -e "\n$is_err $*\n" && exit 1
}

warn() {
    echo -e "\n$is_warn $*\n"
}

##
## 错误输出函数 (T8)
##
error_out() {
    local code="$1"
    local msg="$2"
    local suggestion="${3:-请查看帮助文档或运行 xray help}"
    echo -e "\n${red}[ERR_${code}] 错误! ${msg}${none}"
    echo -e "${yellow}建议: ${suggestion}${none}\n"
}

warn_out() {
    echo -e "\n${yellow}[WARN] 警告! $*${none}\n"
}

## >>> start: TODO 修复BUG #1:安全：强制 ROOT 权限
# root
[[ $EUID != 0 ]] && {
    error_out "PERMISSION" "当前非 ROOT 用户，无法继续安装" "请使用 sudo 或切换到 ROOT 用户执行: sudo bash $0"
    exit $ERR_PERMISSION
}
## <<< end

# yum or apt-get, ubuntu/debian/centos
cmd=$(type -P apt-get || type -P yum)
[[ ! $cmd ]] && {
    error_out "DEPENDENCY" "不支持的操作系统，仅支持 Ubuntu/Debian/CentOS" "请确认系统版本: cat /etc/os-release"
    exit $ERR_DEPENDENCY
}

# systemd
[[ ! $(type -P systemctl) ]] && {
    error_out "DEPENDENCY" "系统缺少 systemctl，请尝试执行: ${cmd} update -y; ${cmd} install systemd -y"
    exit $ERR_DEPENDENCY
}

# wget installed or none
is_wget=$(type -P wget)

# x64
case $(uname -m) in
amd64 | x86_64)
    is_jq_arch=amd64
    is_core_arch="64"
    caddy_arch="amd64"
    ;;
*aarch64* | *armv8*)
    is_jq_arch=arm64
    is_core_arch="arm64-v8a"
    caddy_arch="arm64"
    ;;
*)
    error_out "ARCH" "不支持的系统架构: $(uname -m)，脚本仅支持 x86_64 或 ARM64" "请使用 64 位系统运行脚本"
    exit $ERR_ARCH
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
is_pkg="wget unzip"
is_config_json=$is_core_dir/config.json # is_config_json = /etc/xray/config.json

# Nginx 变量
is_nginx_bin=/usr/sbin/nginx              # is_nginx_bin  = /usr/sbin/nginx
is_nginx_dir=/etc/nginx                 # is_nginx_dir  = /etc/nginx
is_nginx_file=$is_nginx_dir/nginx.conf  # is_nginx_file = /etc/nginx/nginx.conf
is_nginx_conf=$is_nginx_dir/$is_core    # is_nginx_conf = /etc/nginx/xray
is_nginx_repo=nginx/nginx

# Caddy 变量
is_caddy_bin=/usr/local/bin/caddy
is_caddy_dir=/etc/caddy
is_caddy_repo=caddyserver/caddy
is_caddy_file=$is_caddy_dir/Caddyfile
is_caddy_conf=$is_caddy_dir/$author
tmp_var_lists=(
    tmpcore
    tmpsh
    tmpjq
    is_core_ok
    is_sh_ok
    is_jq_ok
    is_pkg_ok
)

tmpcore=
tmpsh=
tmpjq=
is_core_ok=
is_sh_ok=
is_jq_ok=
is_pkg_ok=

# tmp dir
tmpdir=$(mktemp -u)
[[ ! $tmpdir ]] && {
    tmpdir=/tmp/tmp-$RANDOM
}

# set up var
for i in "${tmp_var_lists[@]}"; do
    export "$i"="$tmpdir/$i"
done

# load bash script.
load() {
    # shellcheck disable=SC1090
    . "$is_sh_dir/src/$1"
}

# wget: 默认验证 SSL 证书，TLS 1.2+
_wget() {
    [[ $proxy ]] && export http_proxy=$proxy https_proxy=$proxy HTTP_PROXY=$proxy HTTPS_PROXY=$proxy
    wget --secure-protocol=TLSv1_2 "$@"
}

# print a mesage
msg() {
    case $1 in
    warn)
        local color=$yellow
        ;;
    err)
        local color=$red
        ;;
    ok)
        local color=$green
        ;;
    esac

    echo -e "${color}$(date +'%T')${none}) ${2}"
}

# show help msg
show_help() {
    echo -e "Usage: $0 [-f xxx | -l | -p xxx | -v xxx | --tls xxx | --uninstall | -h]"
    echo -e "  -f, --core-file <path>          自定义 $is_core_name 文件路径, e.g., -f /root/${is_core}-linux-64.zip"
    echo -e "  -l, --local-install             本地获取安装脚本, 使用当前目录"
    echo -e "  -p, --proxy <addr>              使用代理下载, e.g., -p http://127.0.0.1:2333"
    echo -e "  -v, --core-version <ver>        自定义 $is_core_name 版本, e.g., -v v5.4.1"
    echo -e "  --tls <caddy|nginx>             选择 TLS 方案，e.g., --tls nginx"
    echo -e "  --uninstall                     卸载 Xray 和相关组件"
    echo -e "  -h, --help                      显示此帮助界面\n"

    exit 0
}

# install dependent pkg
install_pkg() {
    cmd_not_found=
    for i in "$@"; do
        [[ ! $(type -P "$i") ]] && cmd_not_found="$cmd_not_found,$i"
    done
    if [[ $cmd_not_found ]]; then
        cmd_not_found=${cmd_not_found#,}
        pkg=${cmd_not_found//,/ }
        IFS=' ' read -r -a pkg_array <<< "$pkg"
        set -- "${pkg_array[@]}"
        msg warn "安装依赖包 >$*"
        if ! $cmd install -y "$@" &>/dev/null; then
            [[ $cmd =~ yum ]] && yum install epel-release -y &>/dev/null
            $cmd update -y &>/dev/null
            if $cmd install -y "$@" &>/dev/null; then
                : >"$is_pkg_ok"
            fi
        else
            : >"$is_pkg_ok"
        fi
    else
        : >"$is_pkg_ok"
    fi
}

# download file
download() {
    case $1 in
    core)
        # Xray-core 使用 Xray 作为文件名
        if [[ "$is_core_repo" == *"XTLS/Xray-core"* ]]; then
            core_file_name="Xray-linux-${is_core_arch}.zip"
        else
            core_file_name="${is_core}-linux-${is_core_arch}.zip"
        fi
        link=https://github.com/${is_core_repo}/releases/latest/download/${core_file_name}
        [[ $is_core_ver ]] && link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${core_file_name}"
        name=$is_core_name
        tmpfile=$tmpcore
        is_ok=$is_core_ok
        ;;
    sh)
        link=https://github.com/${is_sh_repo}/releases/latest/download/code.zip
        name="$is_core_name 脚本"
        tmpfile=$tmpsh
        is_ok=$is_sh_ok
        ;;
    jq)
        link=https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$is_jq_arch
        name="jq"
        tmpfile=$tmpjq
        is_ok=$is_jq_ok
        ;;
    esac

    msg warn "下载 ${name} > ${link}"
    if _wget -t 3 -q -c "$link" -O "$tmpfile"; then
        ## SHA256 校验 (仅 Xray-core)
        if [[ $1 == "core" ]]; then
            dgst_link="${link}.dgst"
            dgst_tmp=$(mktemp)
            if _wget -t 3 -q -c "$dgst_link" -O "$dgst_tmp" 2>/dev/null; then
                expected_sha=$(grep 'SHA2-256=' "$dgst_tmp" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]')
                if [[ -n "$expected_sha" ]]; then
                    actual_sha=$(sha256sum "$tmpfile" | awk '{print $1}')
                    if [[ "$actual_sha" == "$expected_sha" ]]; then
                        msg ok "${name} 文件完整性验证通过"
                    else
                        rm -f "$dgst_tmp"
                        err "${name} 文件校验和不匹配."
                    fi
                else
                    msg warn "无法获取 ${name} 校验和，跳过验证"
                fi
            else
                msg warn "无法获取 ${name} 校验文件，跳过验证"
            fi
            rm -f "$dgst_tmp"
        fi
        mv -f "$tmpfile" "$is_ok"
    fi
}

# get server ip
get_ip() {
    export "$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
    [[ -z $ip ]] && export "$(_wget -6 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
}

# check background tasks status
check_status() {
    # dependent pkg install fail
    [[ ! -f "$is_pkg_ok" ]] && {
        error_out "DEPENDENCY" "安装依赖包失败" "请尝试手动安装: $cmd update -y; $cmd install -y $is_pkg"
        is_fail=1
    }

    # download file status
    if [[ $is_wget ]]; then
        [[ ! -f "$is_core_ok" ]] && {
            error_out "DOWNLOAD" "下载 ${is_core_name} 失败" "检查网络或配置代理后重试"
            is_fail=1
        }
        [[ ! -f "$is_sh_ok" ]] && {
            error_out "DOWNLOAD" "下载 ${is_core_name} 脚本失败" "检查网络或配置代理后重试"
            is_fail=1
        }
        [[ ! -f "$is_jq_ok" ]] && {
            error_out "DOWNLOAD" "下载 jq 失败" "检查网络或配置代理后重试"
            is_fail=1
        }
    else
        [[ ! $is_fail ]] && {
            is_wget=1
            # 顺序下载替代并行 & (避免竞态条件 T7)
            [[ ! $is_core_file ]] && download core
            [[ ! $local_install ]] && download sh
            [[ $jq_not_found ]] && download jq
            get_ip
            check_status
        }
    fi

    # found fail status, remove tmp dir and exit.
    [[ $is_fail ]] && {
        exit_and_del_tmpdir
    }
}

# parameters check
pass_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        online)
            err "如果想要安装旧版本, 请转到: https://github.com/WangYan-Good/v2ray/tree/old"
            ;;
        -f | --core-file)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 /root/$is_core-linux-64.zip]"
            } || [[ ! -f $2 ]] && {
                err "($2) 不是一个常规的文件."
            }
            is_core_file=$2
            shift 2
            ;;
        -l | --local-install)
            [[ ! -f "${PWD}/src/core.sh" || ! -f "${PWD}/$is_core.sh" ]] && {
                err "当前目录 (${PWD}) 非完整的脚本目录."
            }
            local_install=1
            shift 1
            ;;
        -p | --proxy)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 http://127.0.0.1:2333 or -p socks5://127.0.0.1:2333]"
            }
            proxy=$2
            export http_proxy=$proxy https_proxy=$proxy HTTP_PROXY=$proxy HTTPS_PROXY=$proxy
            shift 2
            ;;
        -v | --core-version)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 v1.8.1]"
            }
            is_core_ver=v${2#v}
            shift 2
            ;;
        --tls)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数，正确使用示例：[$1 caddy | $1 nginx]"
            }
            case ${2,,} in
            caddy)
                is_install_caddy=1
                ;;
            nginx)
                is_install_nginx=1
                ;;
            *)
                err "不支持的 TLS 方案：$2 (可选：caddy, nginx)"
                ;;
            esac
            shift 2
            ;;
        -h | --help)
            show_help
            ;;
        --uninstall)
            # 执行卸载
            if [[ -f "$is_sh_bin" ]]; then
                "$is_sh_bin" uninstall
            else
                # 直接删除文件
                rm -rf "$is_core_dir" "$is_log_dir" "$is_sh_bin"
                sed -i "/$is_core/d" /root/.bashrc
                # 如果选择了卸载 caddy/nginx
                if [[ -f /usr/local/bin/caddy ]]; then
                    systemctl stop caddy &>/dev/null
                    systemctl disable caddy &>/dev/null
                    rm -rf /etc/caddy /usr/local/bin/caddy /lib/systemd/system/caddy.service
                fi
                if [[ -f /usr/sbin/nginx ]]; then
                    systemctl stop nginx &>/dev/null
                    systemctl disable nginx &>/dev/null
                    rm -rf /etc/nginx /lib/systemd/system/nginx.service
                fi
                msg ok "卸载完成!"
            fi
            exit
            ;;
        *)
            echo -e "\n${is_err} $*\n"
            show_help
            ;;
        esac
    done
    [[ $is_core_ver && $is_core_file ]] && {
        err "无法同时自定义 ${is_core_name} 版本和 ${is_core_name} 文件."
    }
}

# exit and remove tmpdir
exit_and_del_tmpdir() {
    rm -rf "$tmpdir"

    # 失败时回滚已安装的文件
    if [[ ! $1 ]]; then
        # 检查是否已安装到系统（通过检查关键文件是否存在）
        if [[ -d "$is_sh_dir" || -d "$is_core_dir/bin" || -f "$is_sh_bin" ]]; then
            msg warn "检测到部分安装文件，正在清理..."

            # 清理 Xray 文件
            [[ -d "$is_sh_dir" ]] && rm -rf "$is_sh_dir" && msg ok "  - 已清理脚本目录"
            [[ -d "$is_core_dir" ]] && rm -rf "$is_core_dir" && msg ok "  - 已清理核心目录"
            [[ -f "$is_sh_bin" ]] && rm -f "$is_sh_bin" && msg ok "  - 已清理命令链接"
            [[ -d "$is_log_dir" ]] && rm -rf "$is_log_dir" && msg ok "  - 已清理日志目录"

            # 清理 bashrc 配置
            if grep -q "$is_core" /root/.bashrc 2>/dev/null; then
                sed -i "/$is_core/d" /root/.bashrc
                msg ok "  - 已清理 /root/.bashrc"
            fi

            # 清理 systemd 配置
            if [[ -f "/etc/systemd/system/$is_core.service" ]]; then
                rm -f "/etc/systemd/system/$is_core.service"
                systemctl daemon-reload
                msg ok "  - 已清理 systemd 配置"
            fi

            msg ok "失败回滚完成"
        fi

        error_out "CONFIG" "安装过程出现错误" "查看详细日志: tail -50 /var/log/xray/install.log (如有) 或反馈问题: https://github.com/${is_sh_repo}/issues"
        exit $ERR_CONFIG
    fi
    exit
}

##
## main, entry point
##
main() {
    ##
    ## check if scripts exists locally.
    ##
    if [[ -f "${PWD}/src/core.sh" && -f "${PWD}/$is_core.sh" ]]; then
        msg warn "检测到本地脚本，使用本地安装模式"
        local_install=1
    fi

    ##
    ## check old version
    ## 检查旧版本（提供交互式选项）
    ##
    [[ -f "$is_sh_bin" && -d "$is_core_dir/bin" && -d "$is_sh_dir" && -d "$is_conf_dir" ]] && {
        echo
        echo -e "${yellow}检测到脚本已安装!${none}"
        echo "当前安装信息:"
        echo "  - 脚本目录：$is_sh_dir"
        echo "  - 核心目录：$is_core_dir/bin"
        echo "  - 配置目录：$is_conf_dir"
        echo "  - 日志目录：$is_log_dir"
        echo
        echo "请选择:"
        echo "1) 重新安装 (保留配置)"
        echo "2) 卸载后重新安装"
        echo "3) 退出"
        echo
        
        while :; do
            echo -ne "请输入选择 [1-3] (默认:3): "
            read -r reinstall_choice
            [[ ! $reinstall_choice ]] && reinstall_choice=3
            case $reinstall_choice in
            1)
                msg warn "执行重新安装..."
                break
                ;;
            2)
                msg warn "执行卸载..."
                if [[ -f $is_sh_bin ]]; then
                    $is_sh_bin uninstall
                else
                    rm -rf $is_sh_dir $is_core_dir $is_conf_dir $is_log_dir
                    sed -i "/$is_core/d" /root/.bashrc
                    msg ok "卸载完成!"
                fi
                msg warn "继续安装..."
                break
                ;;
            3)
                echo "已退出安装程序"
                echo "如需重新安装，请使用：$is_core reinstall"
                exit 0
                ;;
            *)
                 echo "输入无效，请输入 1-3"
                ;;
            esac
        done
    }

    ##
    ## check parameters
    ## $# 表示传递给脚本的参数个数
    ## -gt 表示 greater than，即大于
    ##
    [[ $# -gt 0 ]] && pass_args "$@"

    ##
    ## show welcome msg
    ##
    echo
    echo "........... $is_core_name script by $author .........."
    echo

    ##
    ## start installing...
    ##
    msg warn "开始安装..."
    [[ $is_core_ver ]] && msg warn "${is_core_name} 版本: ${yellow}$is_core_ver${none}"
    [[ $proxy ]] && msg warn "使用代理: ${yellow}$proxy${none}"
    
    ##
    ## create tmpdir
    ##
    mkdir -p "$tmpdir"
    
    ##
    ## if is_core_file, copy file
    ##
    [[ $is_core_file ]] && {
        cp -f "$is_core_file" "$is_core_ok"
        msg warn "${yellow}${is_core_name} 文件使用 > $is_core_file${none}"
    }
    ##
    ## local dir install sh script
    ##
    [[ $local_install ]] && {
        : >"$is_sh_ok"
        msg warn "${yellow}本地获取安装脚本 > $PWD ${none}"
    }

    if ! timedatectl set-ntp true &>/dev/null; then
        msg warn "${yellow}\e[4m提醒!!! 无法设置自动同步时间, 可能会影响使用 VMess 协议.${none}"
    fi

    # [步骤 1/10] 准备安装环境
    msg warn "[步骤 1/10] 准备安装环境..."
    mkdir -p "$tmpdir"
    [[ $is_core_file ]] && {
        cp -f "$is_core_file" "$is_core_ok"
        msg ok "  - 使用自定义核心文件"
    }
    [[ $local_install ]] && {
        : >"$is_sh_ok"
        msg ok "  - 本地获取安装脚本"
    }
    msg ok "  - 安装环境准备完成"
    
    # [步骤 2/10] 同步系统时间
    msg warn "[步骤 2/10] 同步系统时间..."
    if timedatectl set-ntp true &>/dev/null; then
        msg ok "  - 系统时间已同步"
    else
        msg warn "  - 提醒：无法设置自动同步时间"
    fi
    

    # [步骤 3/10] 安装依赖包
    msg warn "[步骤 3/10] 安装依赖包..."
    read -r -a _pkg_list <<< "$is_pkg"
    install_pkg "${_pkg_list[@]}" &
    msg ok "  - 依赖包安装进行中 (后台)"

    # [步骤 4/10] 检查 jq
    msg warn "[步骤 4/10] 检查 jq..."
    if [[ $(type -P jq) ]]; then
        : >"$is_jq_ok"
        msg ok "  - jq 已安装"
    else
        jq_not_found=1
        msg warn "  - jq 未安装，将自动下载"
    fi
    # [步骤 5/10] 下载必要文件
    msg warn "[步骤 5/10] 下载必要文件..."
    [[ $is_wget ]] && {
        # 顺序下载替代并行 & (避免竞态条件 T7)
        if [[ ! $is_core_file ]]; then
            msg warn "  - 开始下载 Xray 核心..."
            download core
            msg ok "  - Xray 核心下载完成"
        fi
        if [[ ! $local_install ]]; then
            msg warn "  - 开始下载脚本..."
            download sh
            msg ok "  - 脚本下载完成"
        fi
        if [[ $jq_not_found ]]; then
            msg warn "  - 开始下载 jq..."
            download jq
            msg ok "  - jq 下载完成"
        fi
        get_ip
        msg ok "  - 已获取服务器 IP"
    }

    # [步骤 6/10] 检查下载状态
    msg warn "[步骤 6/10] 检查下载状态..."
    msg ok "  - 所有文件下载完成"

    # [步骤 7/10] 检查下载状态
    msg warn "[步骤 7/10] 检查下载状态..."
    check_status
    msg ok "  - 所有文件检查通过"

    # [步骤 8/10] 测试核心文件
    msg warn "[步骤 8/10] 测试核心文件..."
    if [[ $is_core_file ]]; then
        if ! unzip -qo "$is_core_ok" -d "$tmpdir/testzip" &>/dev/null; then
            error_out "CONFIG" "核心文件解压失败" "检查核心文件是否损坏: $is_core_file"
            exit_and_del_tmpdir
        fi
        for i in ${is_core} geoip.dat geosite.dat; do
            [[ ! -f "$tmpdir/testzip/$i" ]] && is_file_err=1 && break
        done
        [[ $is_file_err ]] && {
            error_out "CONFIG" "核心文件不完整" "请重新下载核心文件或检查文件来源"
            exit_and_del_tmpdir
        }
        msg ok "  - 核心文件测试通过"
    else
        msg ok "  - 使用官方核心文件"
    fi

    # [步骤 9/10] 获取服务器 IP
    msg warn "[步骤 9/10] 获取服务器 IP..."
    [[ ! $ip ]] && {
        error_out "CONFIG" "获取服务器 IP 失败" "1. 检查网络: ping 1.1.1.1  2. 检查 DNS 配置  3. 手动指定 IP"
        exit_and_del_tmpdir
    }
    msg ok "  - 服务器 IP: $ip"

    # [步骤 10/10] 安装文件到系统
    msg warn "[步骤 10/10] 安装文件到系统..."
    
    # create sh dir
    mkdir -p $is_sh_dir
    msg ok "  - 已创建脚本目录"

    # copy sh file
    if [[ $local_install ]]; then
            cp -rf "$PWD"/* "$is_sh_dir"
            msg ok "  - 已复制本地脚本"
        else
            unzip -qo "$is_sh_ok" -d "$is_sh_dir"
    fi

    # create core bin dir
    mkdir -p "$is_core_dir/bin"
    msg ok "  - 已创建核心目录"
    
    # copy core file
    if [[ $is_core_file ]]; then
        cp -rf "$tmpdir/testzip"/* "$is_core_dir/bin"
        msg ok "  - 已复制核心文件"
    else
        unzip -qo "$is_core_ok" -d "$is_core_dir/bin"
        msg ok "  - 已解压核心文件"
    fi

    # add alias
    echo "alias $is_core=$is_sh_bin" >>/root/.bashrc
    msg ok "  - 已添加别名"

    # core command
    ln -sf "$is_sh_dir/$is_core.sh" "$is_sh_bin"
    msg ok "  - 已创建命令链接"

    # jq
    [[ $jq_not_found ]] && mv -f "$is_jq_ok" /usr/bin/jq && msg ok "  - 已安装 jq"

    # chmod
    chmod +x "$is_core_bin" "$is_sh_bin" /usr/bin/jq
    msg ok "  - 已设置执行权限：$is_core_bin, $is_sh_bin, /usr/bin/jq (+x)"

    # create log dir
    mkdir -p "$is_log_dir"
    msg ok "  - 已创建日志目录：$is_log_dir (access.log, error.log)"

    # show a tips msg
    msg ok "生成配置文件..."

    # create systemd service
    load systemd.sh
    is_new_install=1
    install_service $is_core &>/dev/null

    # setup system-wide limits (file descriptors, fs.file-max)
    msg ok "  - 正在配置系统级限制..."
    setup_system_limits &>/dev/null
    msg ok "  - 系统级限制已配置 (LimitNOFILE=1048576)"

    # setup log rotation
    load log.sh
    setup_logrotate &>/dev/null
    msg ok "  - 日志轮转已配置 (/etc/logrotate.d/$is_core)"

    # create condf dir
    mkdir -p $is_conf_dir

    # TLS 方案选择
    if [[ ! $is_install_caddy && ! $is_install_nginx ]]; then
        # 检测已安装的服务
        is_caddy_installed=
        is_nginx_installed=
        [[ -f /usr/local/bin/caddy || $(type -P caddy) ]] && is_caddy_installed=1
        [[ -f /usr/sbin/nginx || $(type -P nginx) ]] && is_nginx_installed=1
        
        echo
        echo -e "${yellow}选择 TLS 配置方案:${none}"
        
        # 根据已安装的服务提供选项
        if [[ $is_caddy_installed && $is_nginx_installed ]]; then
            echo "检测到 Caddy 和 Nginx 都已安装，请选择:"
            echo "1) 使用 Caddy"
            echo "2) 使用 Nginx"
            echo "3) 停止 Caddy，使用 Nginx"
            echo "4) 停止 Nginx，使用 Caddy"
            
            while :; do
                echo -ne "请输入选择 [1-4] (默认:2): "
                read -r tls_choice
                [[ ! $tls_choice ]] && tls_choice=2
                case $tls_choice in
                1)
                    is_install_caddy=1
                    break
                    ;;
                2)
                    is_install_nginx=1
                    break
                    ;;
                3)
                    msg warn "停止 Caddy..."
                    systemctl stop caddy &>/dev/null
                    systemctl disable caddy &>/dev/null
                    is_install_nginx=1
                    break
                    ;;
                4)
                    msg warn "停止 Nginx..."
                    systemctl stop nginx &>/dev/null
                    systemctl disable nginx &>/dev/null
                    is_install_caddy=1
                    break
                    ;;
                *)
                     echo "输入无效，请输入 1-4"
                    ;;
                esac
            done
        elif [[ $is_caddy_installed ]]; then
            echo "检测到 Caddy 已安装，请选择:"
            echo "1) 使用 Caddy (默认)"
            echo "2) 停止 Caddy，改用 Nginx"
            
            while :; do
                echo -ne "请输入选择 [1-2] (默认:1): "
                read -r tls_choice
                [[ ! $tls_choice ]] && tls_choice=1
                case $tls_choice in
                1)
                    is_install_caddy=1
                    break
                    ;;
                2)
                    msg warn "停止 Caddy..."
                    systemctl stop caddy &>/dev/null
                    systemctl disable caddy &>/dev/null
                    is_install_nginx=1
                    break
                    ;;
                *)
                     echo "输入无效，请输入 1-2"
                    ;;
                esac
            done
        elif [[ $is_nginx_installed ]]; then
            echo "检测到 Nginx 已安装，请选择:"
            echo "1) 使用 Nginx (默认)"
            echo "2) 停止 Nginx，改用 Caddy"
            
            while :; do
                echo -ne "请输入选择 [1-2] (默认:1): "
                read -r tls_choice
                [[ ! $tls_choice ]] && tls_choice=1
                case $tls_choice in
                1)
                    is_install_nginx=1
                    break
                    ;;
                2)
                    msg warn "停止 Nginx..."
                    systemctl stop nginx &>/dev/null
                    systemctl disable nginx &>/dev/null
                    is_install_caddy=1
                    break
                    ;;
                *)
                     echo "输入无效，请输入 1-2"
                    ;;
                esac
            done
        else
            # 都没有安装，提供标准选项
            echo "1) Caddy (简洁，适合单站点)"
            echo "2) Nginx + Certbot (灵活，适合多站点共存) (默认)"
            
            while :; do
                echo -ne "请输入选择 [1-2] (默认:2): "
                read -r tls_choice
                [[ ! $tls_choice ]] && tls_choice=2
                case $tls_choice in
                1)
                    is_install_caddy=1
                    break
                    ;;
                2)
                    is_install_nginx=1
                    break
                    ;;
                *)
                     echo "输入无效，请输入 1-2"
                    ;;
                esac
            done
        fi
    fi

    ##
    ## 冲突预检：确保选定的方案端口不会被另一个运行中的服务占用
    ##
    if [[ $is_install_caddy ]]; then
        if [[ $(systemctl is-active nginx) == "active" ]]; then
            error_out "CONFIG" "您选择了使用 Caddy，但 Nginx 正在运行中，占用了 80/443 端口" "执行以下命令停止 Nginx 后重试: systemctl stop nginx && systemctl disable nginx"
            exit 1
        fi
    elif [[ $is_install_nginx ]]; then
        if [[ $(systemctl is-active caddy) == "active" ]]; then
            error_out "CONFIG" "您选择了使用 Nginx，但 Caddy 正在运行中，占用了 80/443 端口" "执行以下命令停止 Caddy 后重试: systemctl stop caddy && systemctl disable caddy"
            exit 1
        fi
    fi

    ##
    ## 加载 core.sh 脚本
    ##
    load core.sh
    
    ##
    ## 初始化 TLS 配置（Nginx 或 Caddy）
    ##
    if [[ $is_install_nginx ]]; then
        msg warn "安装并初始化 Nginx 配置..."
        load nginx.sh
        install_nginx_certbot || exit_and_del_tmpdir
        load systemd.sh
        install_service nginx &>/dev/null
        create nginx new || exit_and_del_tmpdir

        ##
        ## 设置 is_nginx 标志，避免端口占用警告
        ##
        is_nginx=1
    elif [[ $is_install_caddy ]]; then
        msg warn "安装并初始化 Caddy 配置..."
        load download.sh
        download caddy || exit_and_del_tmpdir
        load systemd.sh
        install_service caddy &>/dev/null
        create caddy new
        
        ##
        ## 设置 is_caddy 标志
        ##
        is_caddy=1
    fi

    ##
    ## 安装完成后引导用户配置第一个节点（与 xray add 完全一致）
    ##
    echo
    echo "=========================================="
    echo "    安装完成！现在配置第一个 Xray 节点"
    echo "=========================================="
    echo

    ##
    ## 显示所有协议选项（与 xray add 命令完全一致）
    ##
    echo "请选择协议类型:"
    # shellcheck disable=SC2154
    for i in "${!protocol_list[@]}"; do
        num=$((i + 1))
        echo "$num) ${protocol_list[$i]}"
    done
    echo "$((${#protocol_list[@]} + 1))) 跳过，稍后手动配置"
    echo

    ##
    ## 处理用户协议选项
    ##
    while :; do
        echo -ne "请输入选择 [1-$((${#protocol_list[@]} + 1))] (默认:1): "
        read -r protocol_choice
        [[ ! $protocol_choice ]] && protocol_choice=1
        
        if [[ $protocol_choice -le ${#protocol_list[@]} ]]; then
            protocol_type=${protocol_list[$((protocol_choice - 1))]}
            break
        elif [[ $protocol_choice -eq $((${#protocol_list[@]} + 1)) ]]; then
            msg ok "已跳过，安装后可以使用 '$is_core add' 命令添加配置"
            exit_and_del_tmpdir ok
        else
            echo "输入无效，请输入 1-$((${#protocol_list[@]} + 1))"
        fi
    done

    ##
    ## 根据协议类型决定是否输入域名
    ## 如果协议是 TLS 类型，就标记需要域名；否则不需要
    ## 自动判断协议是否需要域名（TLS 必须要）
    ##
    is_need_domain=
    case ${protocol_type,,} in
        *-tls) is_need_domain=1 ;;
    esac

    if [[ $is_need_domain ]]; then
        echo
        echo "请输入域名 (例如：xray.example.com):"

        ##
        ## 域名验证循环
        ##
        while :; do
            read -r -p "> " domain_input

            ##
            ## 此协议需要域名，不能为空
            ##
            if [[ -z "$domain_input" ]]; then
                error_out "DOMAIN" "此协议需要域名，请输入" "格式示例: example.com"
                continue
            fi

            ##
            ## 验证域名格式：字母、数字、连字符、点号组成，且至少有一个点号，顶级域名至少2个字符
            ##
            if echo "$domain_input" | grep -E -q '^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?\.[a-zA-Z]{2,}$'; then
                ##
                ## 格式正确，退出循环
                ##
                break
            else
                error_out "DOMAIN" "无效的域名格式: $domain_input" "格式示例: example.com (字母、数字、连字符、点号)"
            fi
        done

        ##
        ## DNS 预检 - 使用多种方式尝试解析域名
        ##
        echo
        msg warn "检查 DNS 解析..."
        resolved_ip=
        if [[ $(type -P nslookup) ]]; then
            resolved_ip=$(nslookup "$domain_input" 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -1)
        elif [[ $(type -P getent) ]]; then
            resolved_ip=$(getent hosts "$domain_input" 2>/dev/null | awk '{ print $1 }')
        elif [[ $(type -P dig) ]]; then
            resolved_ip=$(dig "$domain_input" +short 2>/dev/null | tail -1)
        else
            msg warn "未找到 DNS 检查工具 (nslookup/getent/dig)，跳过 DNS 预检"
        fi

        if [[ -n "$resolved_ip" ]]; then
            if [[ "$resolved_ip" != "$ip" ]]; then
                error_out "DOMAIN" "域名 $domain_input 未解析到服务器 IP: $ip (当前: $resolved_ip)" "1. 添加 DNS A 记录指向 $ip  2. 等待 DNS 生效  3. 继续配置(可能失败)"
                msg warn "当前解析: $resolved_ip"
                echo
                echo "请选择:"
                echo "1) 继续配置（可能失败）"
                echo "2) 退出，配置 DNS 后重试"
                read -r -p "请选择 [1-2] (默认:1): " dns_choice
                [[ ! $dns_choice ]] && dns_choice=1
                if [[ "$dns_choice" == "2" ]]; then
                    msg warn "安装已结束，配置 DNS 后请重新运行安装脚本"
                    exit_and_del_tmpdir
                fi
            else
                msg ok "域名已正确解析到 $ip"
            fi
        else
            msg warn "无法获取域名 IP 地址，跳过 DNS 预检"
            msg warn "请确保域名已正确解析到服务器 IP: $ip"
        fi
    else
        msg "此协议不需要域名"
        echo
        echo "请选择配置方式:"
        echo "1) 自动配置（随机生成端口、密码等参数）"
        echo "2) 跳过，稍后手动配置"
        read -r -p "请选择 [1-2] (默认:1): " config_choice
        [[ ! $config_choice ]] && config_choice=1

        if [[ $config_choice == "1" ]]; then
            is_auto_config=1
        else
            is_skip_config=1
        fi
    fi

    if [[ $domain_input ]]; then
        echo
        msg warn "正在配置 ${yellow}$protocol_type${none} > ${yellow}$domain_input${none}..."

        ##
        ## 添加 域名+协议 配置
        ##
        add "$protocol_type" "$domain_input"
        echo

        ##
        ## 检查 Xray 服务是否正常运行
        ##
        if systemctl is-active --quiet $is_core; then
            msg ok "配置完成！使用 '$is_core info' 查看配置信息"
        else
            error_out "SERVICE" "Xray 服务启动失败" "1. 检查 DNS: nslookup $domain_input | grep $ip  2. 检查端口: ss -tlnp | grep :80  3. 查看日志: $is_core logerr  4. 重试: $is_core add $protocol_type $domain_input"
            exit_and_del_tmpdir
        fi
    elif [[ $is_auto_config ]]; then
        echo
        msg warn "正在自动配置 ${yellow}$protocol_type${none}..."

        ##
        ## 使用 auto 参数自动配置
        ##
        add "$protocol_type" auto
        echo

        ##
        ## 检查 Xray 服务是否正常运行
        ##
        if systemctl is-active --quiet $is_core; then
            msg ok "配置完成！使用 '$is_core info' 查看配置信息"
        else
            error_out "SERVICE" "Xray 服务启动失败" "1. 查看日志: $is_core logerr  2. 修复: $is_core fix-all  3. 重试: $is_core add $protocol_type"
            exit_and_del_tmpdir
        fi
    else
        msg warn "已跳过，安装后可以使用 '$is_core add' 命令添加配置"
        echo
        echo "=========================================="
        echo "    安装完成"
        echo "=========================================="
        echo
        echo "请使用以下命令添加配置："
        echo "  $is_core add vmess-ws-tls yourdomain.com  # TLS 加密（推荐）"
        echo "  $is_core add vmess-tcp                    # 非 TLS"
        echo "  $is_core add ss                           # Shadowsocks"
        echo "  $is_core add socks                        # Socks 代理"
        echo "  $is_core help                             # 查看完整帮助"
        echo
    fi

    ##
    ## 删除临时文件并退出
    ##
    exit_and_del_tmpdir ok
}

##
## start, input all parameters
##
main "$@"
