#!/bin/bash

author=WangYan-Good
# github=https://github.com/WangYan-Good/v2ray

# bash fonts colors
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

is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)

err() {
    echo -e "\n$is_err $@\n" && exit 1
}

warn() {
    echo -e "\n$is_warn $@\n"
}

# root
[[ $EUID != 0 ]] && err "当前非 ${yellow}ROOT用户.${none}"

# yum or apt-get, ubuntu/debian/centos
cmd=$(type -P apt-get || type -P yum)
[[ ! $cmd ]] && err "此脚本仅支持 ${yellow}(Ubuntu or Debian or CentOS)${none}."

# systemd
[[ ! $(type -P systemctl) ]] && {
    err "此系统缺少 ${yellow}(systemctl)${none}, 请尝试执行:${yellow} ${cmd} update -y;${cmd} install systemd -y ${none}来修复此错误."
}

# wget installed or none
is_wget=$(type -P wget)

# x64
case $(uname -m) in
amd64 | x86_64)
    is_jq_arch=amd64
    is_core_arch="64"
    ;;
*aarch64* | *armv8*)
    is_jq_arch=arm64
    is_core_arch="arm64-v8a"
    ;;
*)
    err "此脚本仅支持 64 位系统..."
    ;;
esac

is_core=v2ray
is_core_name=V2Ray
is_core_dir=/etc/$is_core
is_core_bin=$is_core_dir/bin/$is_core
is_core_repo=v2fly/$is_core-core
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/$is_core
is_sh_dir=$is_core_dir/sh
is_sh_repo=$author/$is_core
is_pkg="wget unzip"
is_config_json=$is_core_dir/config.json

# Nginx 变量
is_nginx_dir=/etc/nginx
is_nginxfile=$is_nginx_dir/nginx.conf
is_nginx_conf=$is_nginx_dir/v2ray

# Caddy 变量
is_caddy_dir=/etc/caddy
is_caddyfile=$is_caddy_dir/Caddyfile
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

# tmp dir
tmpdir=$(mktemp -u)
[[ ! $tmpdir ]] && {
    tmpdir=/tmp/tmp-$RANDOM
}

# set up var
for i in ${tmp_var_lists[*]}; do
    export $i=$tmpdir/$i
done

# load bash script.
load() {
    . $is_sh_dir/src/$1
}

# wget add --no-check-certificate
_wget() {
    [[ $proxy ]] && export https_proxy=$proxy
    wget --no-check-certificate $*
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
    echo -e "  --uninstall                     卸载 V2Ray 和相关组件"
    echo -e "  -h, --help                      显示此帮助界面\n"

    exit 0
}

# install dependent pkg
install_pkg() {
    cmd_not_found=
    for i in $*; do
        [[ ! $(type -P $i) ]] && cmd_not_found="$cmd_not_found,$i"
    done
    if [[ $cmd_not_found ]]; then
        pkg=$(echo $cmd_not_found | sed 's/,/ /g')
        msg warn "安装依赖包 >${pkg}"
        $cmd install -y $pkg &>/dev/null
        if [[ $? != 0 ]]; then
            [[ $cmd =~ yum ]] && yum install epel-release -y &>/dev/null
            $cmd update -y &>/dev/null
            $cmd install -y $pkg &>/dev/null
            [[ $? == 0 ]] && >$is_pkg_ok
        else
            >$is_pkg_ok
        fi
    else
        >$is_pkg_ok
    fi
}

# download file
download() {
    case $1 in
    core)
        link=https://github.com/${is_core_repo}/releases/latest/download/${is_core}-linux-${is_core_arch}.zip
        [[ $is_core_ver ]] && link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${is_core}-linux-${is_core_arch}.zip"
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
    if _wget -t 3 -q -c $link -O $tmpfile; then
        mv -f $tmpfile $is_ok
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
    [[ ! -f $is_pkg_ok ]] && {
        msg err "安装依赖包失败"
        msg err "请尝试手动安装依赖包: $cmd update -y; $cmd install -y $is_pkg"
        is_fail=1
    }

    # download file status
    if [[ $is_wget ]]; then
        [[ ! -f $is_core_ok ]] && {
            msg err "下载 ${is_core_name} 失败"
            is_fail=1
        }
        [[ ! -f $is_sh_ok ]] && {
            msg err "下载 ${is_core_name} 脚本失败"
            is_fail=1
        }
        [[ ! -f $is_jq_ok ]] && {
            msg err "下载 jq 失败"
            is_fail=1
        }
    else
        [[ ! $is_fail ]] && {
            is_wget=1
            [[ ! $is_core_file ]] && download core &
            [[ ! $local_install ]] && download sh &
            [[ $jq_not_found ]] && download jq &
            get_ip
            wait
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
            [[ ! -f ${PWD}/src/core.sh || ! -f ${PWD}/$is_core.sh ]] && {
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
            if [[ -f /usr/local/bin/v2ray ]]; then
                v2ray uninstall
            else
                # 直接删除文件
                rm -rf /etc/v2ray /var/log/v2ray /usr/local/bin/v2ray
                sed -i '/v2ray/d' /root/.bashrc
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
            echo -e "\n${is_err} ($@) 为未知参数...\n"
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
    rm -rf $tmpdir
    [[ ! $1 ]] && {
        msg err "哦豁.."
        msg err "安装过程出现错误..."
        echo -e "反馈问题) https://github.com/${is_sh_repo}/issues"
        echo
        exit 1
    }
    exit
}

# main
main() {

    # 先检查是否有 --uninstall 参数（需要在检查已安装之前处理）
    for arg in "$@"; do
        if [[ $arg == '--uninstall' ]]; then
            msg warn "开始卸载 V2Ray 和相关组件..."
            
            # 步骤 1: 检查并卸载 V2Ray
            if [[ -f /usr/local/bin/v2ray ]]; then
                msg warn "[步骤 1/6] 检测到 v2ray 命令，使用交互式卸载..."
                v2ray uninstall
                exit
            fi
            
            # 步骤 1: 删除 V2Ray 文件
            msg warn "[步骤 1/6] 删除 V2Ray 文件..."
            if [[ -d /etc/v2ray ]]; then
                rm -rf /etc/v2ray
                msg ok "  - 已删除 /etc/v2ray"
            fi
            if [[ -d /var/log/v2ray ]]; then
                rm -rf /var/log/v2ray
                msg ok "  - 已删除 /var/log/v2ray"
            fi
            if [[ -f /usr/local/bin/v2ray ]]; then
                rm -f /usr/local/bin/v2ray
                msg ok "  - 已删除 /usr/local/bin/v2ray"
            fi
            
            # 步骤 2: 清理 bashrc
            msg warn "[步骤 2/6] 清理 bashrc 配置..."
            sed -i '/v2ray/d' /root/.bashrc
            msg ok "  - 已清理 /root/.bashrc"
            
            # 步骤 3: 停止并卸载 Caddy（如果存在）
            if [[ -f /usr/local/bin/caddy ]]; then
                msg warn "[步骤 3/6] 检测到 Caddy，停止并卸载..."
                systemctl stop caddy &>/dev/null && msg ok "  - 已停止 Caddy 服务"
                systemctl disable caddy &>/dev/null && msg ok "  - 已禁用 Caddy 服务"
                rm -rf /etc/caddy /usr/local/bin/caddy /lib/systemd/system/caddy.service
                msg ok "  - 已删除 Caddy 文件"
            else
                msg warn "[步骤 3/6] 未检测到 Caddy，跳过"
            fi
            
            # 步骤 4: 停止并卸载 Nginx（如果存在）
            if [[ -f /usr/sbin/nginx ]]; then
                msg warn "[步骤 4/6] 检测到 Nginx，停止并卸载..."
                systemctl stop nginx &>/dev/null && msg ok "  - 已停止 Nginx 服务"
                systemctl disable nginx &>/dev/null && msg ok "  - 已禁用 Nginx 服务"
                rm -rf /etc/nginx /lib/systemd/system/nginx.service
                msg ok "  - 已删除 Nginx 文件"
            else
                msg warn "[步骤 4/6] 未检测到 Nginx，跳过"
            fi
            
            # 步骤 5: 清理 systemd
            msg warn "[步骤 5/6] 清理 systemd 配置..."
            systemctl daemon-reload &>/dev/null
            msg ok "  - 已重载 systemd 配置"
            
            # 步骤 6: 完成
            msg warn "[步骤 6/6] 卸载完成!"
            msg ok "\n卸载完成！"
            msg "已删除:"
            msg "  - V2Ray 核心和脚本"
            [[ -f /usr/local/bin/caddy ]] || msg "  - Caddy (如果已安装)"
            [[ -f /usr/sbin/nginx ]] || msg "  - Nginx (如果已安装)"
            msg "\n如需重新安装，请运行：./install.sh"
            exit
        fi
    done

    # 自动检测本地安装模式
    if [[ -f ${PWD}/src/core.sh && -f ${PWD}/v2ray.sh ]]; then
        msg warn "检测到本地脚本，使用本地安装模式"
        local_install=1
    fi

    # check old version
    # 检查旧版本（提供交互式选项）
    [[ -f $is_sh_bin && -d $is_core_dir/bin && -d $is_sh_dir && -d $is_conf_dir ]] && {
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
            read reinstall_choice
            [[ ! $reinstall_choice ]] && reinstall_choice=3
            case $reinstall_choice in
            1)
                msg warn "执行重新安装..."
                break
                ;;
            2)
                msg warn "执行卸载..."
                if [[ -f /usr/local/bin/v2ray ]]; then
                    v2ray uninstall
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

    # check parameters
    [[ $# -gt 0 ]] && pass_args $@

    # show welcome msg
    clear
    echo
    echo "........... $is_core_name script by $author .........."
    echo

    # start installing...
    msg warn "开始安装..."
    [[ $is_core_ver ]] && msg warn "${is_core_name} 版本: ${yellow}$is_core_ver${none}"
    [[ $proxy ]] && msg warn "使用代理: ${yellow}$proxy${none}"
    # create tmpdir
    mkdir -p $tmpdir
    # if is_core_file, copy file
    [[ $is_core_file ]] && {
        cp -f $is_core_file $is_core_ok
        msg warn "${yellow}${is_core_name} 文件使用 > $is_core_file${none}"
    }
    # local dir install sh script
    [[ $local_install ]] && {
        >$is_sh_ok
        msg warn "${yellow}本地获取安装脚本 > $PWD ${none}"
    }

    timedatectl set-ntp true &>/dev/null
    [[ $? != 0 ]] && {
        msg warn "${yellow}\e[4m提醒!!! 无法设置自动同步时间, 可能会影响使用 VMess 协议.${none}"
    }

    # [步骤 1/10] 准备安装环境
    msg warn "[步骤 1/10] 准备安装环境..."
    mkdir -p $tmpdir
    [[ $is_core_file ]] && {
        cp -f $is_core_file $is_core_ok
        msg ok "  - 使用自定义核心文件"
    }
    [[ $local_install ]] && {
        >$is_sh_ok
        msg ok "  - 本地获取安装脚本"
    }
    msg ok "  - 安装环境准备完成"
    
    # [步骤 2/10] 同步系统时间
    msg warn "[步骤 2/10] 同步系统时间..."
    timedatectl set-ntp true &>/dev/null
    [[ $? != 0 ]] && msg warn "  - 提醒：无法设置自动同步时间" || msg ok "  - 系统时间已同步"
    

    # [步骤 3/10] 安装依赖包
    msg warn "[步骤 3/10] 安装依赖包..."
    install_pkg $is_pkg &
    msg ok "  - 依赖包安装进行中 (后台)"

    # [步骤 4/10] 检查 jq
    msg warn "[步骤 4/10] 检查 jq..."
    if [[ $(type -P jq) ]]; then
        >$is_jq_ok
        msg ok "  - jq 已安装"
    else
        jq_not_found=1
        msg warn "  - jq 未安装，将自动下载"
    fi
    # [步骤 5/10] 下载必要文件
    msg warn "[步骤 5/10] 下载必要文件..."
    [[ $is_wget ]] && {
        [[ ! $is_core_file ]] && { download core & msg ok "  - 开始下载 V2Ray 核心"; }
        [[ ! $local_install ]] && { download sh & msg ok "  - 开始下载脚本"; }
        [[ $jq_not_found ]] && { download jq & msg ok "  - 开始下载 jq"; }
        get_ip
        msg ok "  - 已获取服务器 IP"
    }

    # [步骤 6/10] 等待下载完成
    msg warn "[步骤 6/10] 等待下载完成..."
    wait
    msg ok "  - 所有文件下载完成"

    # [步骤 7/10] 检查下载状态
    msg warn "[步骤 7/10] 检查下载状态..."
    check_status
    msg ok "  - 所有文件检查通过"

    # [步骤 8/10] 测试核心文件
    msg warn "[步骤 8/10] 测试核心文件..."
    if [[ $is_core_file ]]; then
        unzip -qo $is_core_ok -d $tmpdir/testzip &>/dev/null
        [[ $? != 0 ]] && {
            msg err "  - 核心文件解压失败"
            exit_and_del_tmpdir
        }
        for i in ${is_core} geoip.dat geosite.dat; do
            [[ ! -f $tmpdir/testzip/$i ]] && is_file_err=1 && break
        done
        [[ $is_file_err ]] && {
            msg err "  - 核心文件不完整"
            exit_and_del_tmpdir
        }
        msg ok "  - 核心文件测试通过"
    else
        msg ok "  - 使用官方核心文件"
    fi

    # [步骤 9/10] 获取服务器 IP
    msg warn "[步骤 9/10] 获取服务器 IP..."
    [[ ! $ip ]] && {
        msg err "  - 获取服务器 IP 失败"
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
        cp -rf $PWD/* $is_sh_dir
        msg ok "  - 已复制本地脚本"
    else
        unzip -qo $is_sh_ok -d $is_sh_dir
        msg ok "  - 已解压脚本文件"
    fi

    # create core bin dir
    mkdir -p $is_core_dir/bin
    msg ok "  - 已创建核心目录"
    
    # copy core file
    if [[ $is_core_file ]]; then
        cp -rf $tmpdir/testzip/* $is_core_dir/bin
        msg ok "  - 已复制核心文件"
    else
        unzip -qo $is_core_ok -d $is_core_dir/bin
        msg ok "  - 已解压核心文件"
    fi

    # add alias
    echo "alias $is_core=$is_sh_bin" >>/root/.bashrc
    msg ok "  - 已添加别名"

    # core command
    ln -sf $is_sh_dir/$is_core.sh $is_sh_bin
    msg ok "  - 已创建命令链接"

    # jq
    [[ $jq_not_found ]] && mv -f $is_jq_ok /usr/bin/jq && msg ok "  - 已安装 jq"

    # chmod
    chmod +x $is_core_bin $is_sh_bin /usr/bin/jq
    msg ok "  - 已设置执行权限：$is_core_bin, $is_sh_bin, /usr/bin/jq (+x)"

    # create log dir
    mkdir -p $is_log_dir
    msg ok "  - 已创建日志目录：$is_log_dir (access.log, error.log)"

    # show a tips msg
    msg ok "生成配置文件..."

    # create systemd service
    load systemd.sh
    is_new_install=1
    install_service $is_core &>/dev/null

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
                read tls_choice
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
                read tls_choice
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
                read tls_choice
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
                read tls_choice
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

    load core.sh
    
    # 初始化 TLS 配置（Nginx 或 Caddy）
    if [[ $is_install_nginx ]]; then
        msg warn "初始化 Nginx 配置..."
        create nginx new
        # 设置 is_nginx 标志，避免端口占用警告
        is_nginx=1
    elif [[ $is_install_caddy ]]; then
        msg warn "初始化 Caddy 配置..."
        create caddy new
        # 设置 is_caddy 标志
        is_caddy=1
    fi

    # 安装完成后引导用户配置第一个节点（与 v2ray add 完全一致）
    echo
    echo "=========================================="
    echo "    安装完成！现在配置第一个 V2Ray 节点"
    echo "=========================================="
    echo
    
    # 显示所有协议选项（与 v2ray add 命令完全一致）
    echo "请选择协议类型:"
    for i in "${!protocol_list[@]}"; do
        num=$((i + 1))
        echo "$num) ${protocol_list[$i]}"
    done
    echo "$((${#protocol_list[@]} + 1))) 跳过，稍后手动配置"
    echo

    while :; do
        echo -ne "请输入选择 [1-$((${#protocol_list[@]} + 1))] (默认:1): "
        read protocol_choice
        [[ ! $protocol_choice ]] && protocol_choice=1
        
        if [[ $protocol_choice -le ${#protocol_list[@]} ]]; then
            protocol_type=${protocol_list[$((protocol_choice - 1))]}
            break
        elif [[ $protocol_choice -eq $((${#protocol_list[@]} + 1)) ]]; then
            msg ok "已跳过，安装后可以使用 'v2ray add' 命令添加配置"
            exit_and_del_tmpdir ok
        else
            echo "输入无效，请输入 1-$((${#protocol_list[@]} + 1))"
        fi
    done

    echo
    echo "请输入域名 (例如：v2ray.example.com):"
    read -p "> " domain_input

    if [[ $domain_input ]]; then
        echo
        msg warn "正在配置 ${yellow}$protocol_type${none} > ${yellow}$domain_input${none}..."
        add $protocol_type $domain_input
        echo
        msg ok "配置完成！使用 'v2ray info' 查看配置信息"
    else
        msg warn "未输入域名，已跳过配置"
    fi

    # remove tmp dir and exit.
    exit_and_del_tmpdir ok
}

# start.
main $@
