#!/bin/bash

AUTHOR=WangYan-Good
# github=https://github.com/WangYan-Good/v2ray

##
## bash 字体颜色
##
RED='\e[31m'
YELLOW='\e[33m'
GRAY='\e[90m'
GREEN='\e[92m'
BLUE='\e[94m'
MAGENTA='\e[95m'
CYAN='\e[96m'
NONE='\e[0m'
_red() { echo -e "${RED}$*${NONE}"; }
_blue() { echo -e "${BLUE}$*${NONE}"; }
_cyan() { echo -e "${CYAN}$*${NONE}"; }
_green() { echo -e "${GREEN}$*${NONE}"; }
_yellow() { echo -e "${YELLOW}$*${NONE}"; }
_magenta() { echo -e "${MAGENTA}$*${NONE}"; }
_red_bg() { echo -e "\e[41m$*${NONE}"; }

IS_ERR=$(_red_bg 错误!)
IS_WARN=$(_red_bg 警告!)

err() {
    echo -e "\n$IS_ERR $*\n"
    [[ $IS_DONT_AUTO_EXIT ]] && return
    exit 1
}

warn() {
    echo -e "\n$IS_WARN $*\n"
}

##
## root 权限检查
##
[[ $EUID != 0 ]] && err "当前非 ${YELLOW}ROOT用户.${NONE}"

##
## yum 或 apt-get, ubuntu/debian/centos
##
CMD=$(type -P apt-get || type -P yum)
[[ ! $CMD ]] && err "此脚本仅支持 ${YELLOW}(Ubuntu or Debian or CentOS)${NONE}."

##
## systemd 检查
##
[[ ! $(type -P systemctl) ]] && {
    err "此系统缺少 ${YELLOW}(systemctl)${NONE}, 请尝试执行:${YELLOW} ${CMD} update -y;${CMD} install systemd -y ${NONE}来修复此错误."
}

##
## wget 是否已安装
##
IS_WGET=$(type -P wget)

##
## 系统架构检查 x64
##
case $(uname -m) in
amd64 | x86_64)
    IS_JQ_ARCH=amd64
    IS_CORE_ARCH="64"
    ;;
*aarch64* | *armv8*)
    IS_JQ_ARCH=arm64
    IS_CORE_ARCH="arm64-v8a"
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
IS_PKG="wget unzip"
IS_CONFIG_JSON=$IS_CORE_DIR/config.json

##
## Nginx 变量
##
IS_NGINX_DIR=/etc/nginx
IS_NGINXFILE=$IS_NGINX_DIR/nginx.conf
IS_NGINX_CONF=$IS_NGINX_DIR/v2ray

##
## Caddy 变量
##
IS_CADDY_DIR=/etc/caddy
IS_CADDYFILE=$IS_CADDY_DIR/Caddyfile
IS_CADDY_CONF=$IS_CADDY_DIR/$AUTHOR
TMP_VAR_LISTS=(
    TMPCORE
    TMPSH
    TMPJQ
    IS_CORE_OK
    IS_SH_OK
    IS_JQ_OK
    IS_PKG_OK
)

##
## 定义临时目录路径
##
TMPDIR=$(mktemp -u)
[[ ! $TMPDIR ]] && {
    ##
    ## 如果 mktemp -u 不支持，使用备用方案
    ##
    TMPDIR=/tmp/tmp-$RANDOM
}

##
## 设置变量
##
for i in "${TMP_VAR_LISTS[@]}"; do
    export "$i=$TMPDIR/$i"
done

##
## 加载 bash 脚本
##
load() {
    # shellcheck source=/dev/null
    . "$IS_SH_DIR/src/$1"
}

##
## wget 添加 --no-check-certificate 参数
##
_wget() {
    [[ $PROXY ]] && export HTTPS_PROXY=$PROXY
    wget --no-check-certificate "$@"
}

##
## 打印消息
##
msg() {
    case $1 in
    WARNING)
        local COLOR=$YELLOW
        ;;
    ERROR)
        local COLOR=$RED
        ;;
    OK)
        local COLOR=$GREEN
        ;;
    esac

    echo -e "${COLOR}$(date +'%T')${NONE}) ${2}"
}

##
## 显示帮助信息
##
show_help() {
    echo -e "Usage: $0 [-f xxx | -l | -p xxx | -v xxx | --tls xxx | --uninstall | -h]"
    echo -e "  -f, --core-file <path>          自定义 $IS_CORE_NAME 文件路径, e.g., -f /root/${IS_CORE}-linux-64.zip"
    echo -e "  -l, --local-install             本地获取安装脚本, 使用当前目录"
    echo -e "  -p, --proxy <addr>              使用代理下载, e.g., -p http://127.0.0.1:2333"
    echo -e "  -v, --core-version <ver>        自定义 $IS_CORE_NAME 版本, e.g., -v v5.4.1"
    echo -e "  --tls <caddy|nginx>             选择 TLS 方案，e.g., --tls nginx"
    echo -e "  --uninstall                     卸载 V2Ray 和相关组件"
    echo -e "  -h, --help                      显示此帮助界面\n"

    exit 0
}

##
## install dependent pkg
## 安装依赖包（如 wget, unzip 等）
## 参数：$* - 需要检查安装的包名列表
##
install_pkg() {
    ##
    ## 1. 检查哪些包未安装
    ## 遍历所有传入的包名，将未找到的包名记录到 CMD_NOT_FOUND
    ##
    local CMD_NOT_FOUND=""
    local pkg=""
    
    for pkg in "$@"; do
        if [[ ! $(type -P "$pkg") ]]; then
            CMD_NOT_FOUND="$CMD_NOT_FOUND,$pkg"
        fi
    done
    
    ##
    ## 2. 如果有未安装的包，执行安装
    ##
    if [[ $CMD_NOT_FOUND ]]; then
        
        ##
        ## 将逗号分隔的列表转换为空格分隔的包名列表
        ##
        PKG=$(echo "$CMD_NOT_FOUND" | sed 's/,/ /g')
        msg WARNING "安装依赖包 >${PKG}"
        
        ##
        ## 3. 第一次尝试安装
        ##
        $CMD install -y "$PKG" &>/dev/null
        
        ##
        ## 4. 如果第一次安装失败，尝试修复后再次安装
        ## 针对 CentOS 系统：先安装 epel-release 源，然后更新系统
        ##
        if [[ $? != 0 ]]; then
            [[ $CMD =~ yum ]] && yum install epel-release -y &>/dev/null
            $CMD update -y &>/dev/null
            $CMD install -y "$PKG" &>/dev/null
            [[ $? == 0 ]] && >"$IS_PKG_OK"
        else
            ##
            ## 第一次安装成功，创建标记文件
            ## 如果第一次安装成功，创建标记文件 $IS_PKG_OK，表示依赖包安装成功
            ##
            >"$IS_PKG_OK"
        fi
    else
        >"$IS_PKG_OK"
    fi
}

##
## 下载文件
##
download() {
    case $1 in
    ##
    ## 核心文件下载链接，支持指定版本和自定义文件
    ##
    core)
        LINK=https://github.com/${IS_CORE_REPO}/releases/latest/download/${IS_CORE}-linux-${IS_CORE_ARCH}.zip
        [[ $IS_CORE_VER ]] && LINK="https://github.com/${IS_CORE_REPO}/releases/download/${IS_CORE_VER}/${IS_CORE}-linux-${IS_CORE_ARCH}.zip"
        NAME=$IS_CORE_NAME
        TMPFILE=$TMPCORE
        IS_OK=$IS_CORE_OK
        ;;
    ##
    ## download the latest code
    ##
    sh)
        LINK=https://github.com/${IS_SH_REPO}/releases/latest/download/code.zip
        NAME="$IS_CORE_NAME 脚本"
        TMPFILE=$TMPSH
        IS_OK=$IS_SH_OK
        ;;
    ##
    ## jq is a lightweight and flexible command-line JSON processor akin to sed,awk,grep, and friends for JSON data. 
    ## It's written in portable C and has zero runtime dependencies, allowing you to easily slice, filter, map, and transform structured data.
    ##
    jq)
        LINK=https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$IS_JQ_ARCH
        NAME="jq"
        TMPFILE=$TMPJQ
        IS_OK=$IS_JQ_OK
        ;;
    esac

    msg WARNING "下载 ${NAME}"
    ##
    ## 使用 wget 下载并显示进度
    ## 显示文件名、百分比、速度、剩余时间
    ##
    if _wget -t 3 -c "$LINK" -O "$TMPFILE" --progress=bar:force 2>&1 | while IFS= read -r LINE; do
        ## 只显示最后一行进度信息
        printf "\r\033[K  - %s: %s" "$NAME" "$LINE"
    done; then
        printf "\n"
        mv -f "$TMPFILE" "$IS_OK"
    else
        printf "\n"
        return 1
    fi
}

##
## 获取服务器 IP
##
get_ip() {
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

    ##
    ## 依次尝试 IPv4 获取，如果成功则跳出循环
    ##
    for service in "${services[@]}"; do
        IP=$(_wget -4 -T 5 -qO- "$service" 2>/dev/null)
        
        ##
        ## 清理可能的空白字符
        ##
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
}

##
## 检查后台任务状态
##
check_status() {
    ##
    ## 依赖包安装失败
    ##
    [[ ! -f $IS_PKG_OK ]] && {
        msg ERROR "安装依赖包失败"
        msg ERROR "请尝试手动安装依赖包: $CMD update -y; $CMD install -y $IS_PKG"
        IS_FAIL=1
    }

    ##
    ## 下载文件状态
    ## 检查核心文件、脚本文件和 jq 的下载状态，如果任何一个下载失败，设置 IS_FAIL 标志
    ## 如果 IS_FAIL 被设置，后续安装过程将被中断，并提示用户检查下载问题
    ##
    if [[ $IS_WGET ]]; then
        [[ ! -f $IS_CORE_OK ]] && {
            msg ERROR "下载 ${IS_CORE_NAME} 失败"
            IS_FAIL=1
        }
        [[ ! -f $IS_SH_OK ]] && {
            msg ERROR "下载 ${IS_CORE_NAME} 脚本失败"
            IS_FAIL=1
        }
        [[ ! -f $IS_JQ_OK ]] && {
            msg ERROR "下载 jq 失败"
            IS_FAIL=1
        }
    else
        [[ ! $IS_FAIL ]] && {
            IS_WGET=1
            [[ ! $IS_CORE_FILE ]] && download core &
            [[ ! $LOCAL_INSTALL ]] && download sh &
            [[ $JQ_NOT_FOUND ]] && download jq &
            get_ip
            wait
            check_status
        }
    fi

    ##
    ## 发现失败状态，删除临时目录并退出
    ##
    [[ $IS_FAIL ]] && {
        exit_and_del_tmpdir
    }
}

##
## 参数检查
##
pass_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        online)
            err "如果想要安装旧版本, 请转到: https://github.com/WangYan-Good/v2ray/tree/old"
            ;;
        -f | --core-file)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 /root/$IS_CORE-linux-64.zip]"
            } || [[ ! -f $2 ]] && {
                err "($2) 不是一个常规的文件."
            }
            IS_CORE_FILE=$2
            shift 2
            ;;
        -l | --local-install)
            [[ ! -f ${PWD}/src/core.sh || ! -f ${PWD}/$IS_CORE.sh ]] && {
                err "当前目录 (${PWD}) 非完整的脚本目录."
            }
            LOCAL_INSTALL=1
            shift 1
            ;;
        -p | --proxy)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 http://127.0.0.1:2333 or -p SOCKS5://127.0.0.1:2333]"
            }
            PROXY=$2
            shift 2
            ;;
        -v | --core-version)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 v1.8.1]"
            }
            IS_CORE_VER=v${2#v}
            shift 2
            ;;
        --tls)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数，正确使用示例：[$1 caddy | $1 nginx]"
            }
            case ${2,,} in
            caddy)
                IS_INSTALL_CADDY=1
                ;;
            nginx)
                IS_INSTALL_NGINX=1
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
        *)
            echo -e "\n${is_err} ($@) 为未知参数...\n"
            show_help
            ;;
        esac
    done
    [[ $IS_CORE_VER && $IS_CORE_FILE ]] && {
        err "无法同时自定义 ${IS_CORE_NAME} 版本和 ${IS_CORE_NAME} 文件."
    }
}

##
## 退出并删除临时目录
##
exit_and_del_tmpdir() {
    rm -rf $TMPDIR
    [[ ! $1 ]] && {
        msg ERROR "哦豁.."
        msg ERROR "安装过程出现错误..."
        echo -e "反馈问题) https://github.com/${IS_SH_REPO}/issues"
        echo
        exit 1
    }
    exit
}

##
## 主函数
##
main() {
    ##
    ## 1.自动检测本地安装模式
    ##
    if [[ -f ${PWD}/src/core.sh && -f ${PWD}/v2ray.sh ]]; then
        msg WARNING "检测到本地脚本，使用本地安装模式"
        LOCAL_INSTALL=1
    fi

    ##
    ## 2.检查旧版本
    ## 检查旧版本（提供交互式选项）
    ##
    [[ -f $IS_SH_BIN && -d $IS_CORE_DIR/bin && -d $IS_SH_DIR && -d $IS_CONF_DIR ]] && {
        echo
        echo -e "${YELLOW}检测到脚本已安装!${NONE}"
        echo "当前安装信息:"
        echo "  - 脚本目录：$IS_SH_DIR"
        echo "  - 核心目录：$IS_CORE_DIR/bin"
        echo "  - 配置目录：$IS_CONF_DIR"
        echo "  - 日志目录：$IS_LOG_DIR"
        echo
        echo "请选择:"
        echo "1) 重新安装 (保留配置)"
        echo "2) 卸载后重新安装"
        echo "3) 退出"
        echo

        while :; do
            echo -ne "请输入选择 [1-3] (默认:3): "
            read REINSTALL_CHOICE
            [[ ! $REINSTALL_CHOICE ]] && REINSTALL_CHOICE=3
            case $REINSTALL_CHOICE in
            1)
                msg WARNING "执行重新安装..."
                break
                ;;
            2)
                msg WARNING "执行卸载..."
                if [[ -f /usr/local/bin/v2ray ]]; then
                    v2ray uninstall
                else
                    rm -rf $IS_SH_DIR $IS_CORE_DIR $IS_CONF_DIR $IS_LOG_DIR
                    sed -i "/$IS_CORE/d" /root/.bashrc
                    msg OK "卸载完成!"
                fi
                msg WARNING "继续安装..."
                break
                ;;
            3)
                echo "已退出安装程序"
                echo "如需重新安装，请使用：$IS_CORE reinstall"
                exit 0
                ;;
            *)
                 echo "输入无效，请输入 1-3"
                ;;
            esac
        done
    }

    ##
    ## 检查参数
    ##
    [[ $# -gt 0 ]] && pass_args $@

    ##
    ## 显示欢迎信息
    ##
    clear
    echo
    echo "........... $IS_CORE_NAME script by $AUTHOR .........."
    echo

    ##
    ## 开始安装...
    ##
    msg WARNING "开始安装..."
    [[ $IS_CORE_VER ]] && msg WARNING "${IS_CORE_NAME} 版本: ${YELLOW}$IS_CORE_VER${NONE}"
    [[ $PROXY ]] && msg WARNING "使用代理: ${YELLOW}$PROXY${NONE}"

    ##
    ## 创建临时目录并设置文件路径
    ##
    mkdir -p $TMPDIR
    
    ##
    ## 如果是 IS_CORE_FILE，复制文件
    ##
    [[ $IS_CORE_FILE ]] && {
        cp -f $IS_CORE_FILE $IS_CORE_OK
        msg WARNING "${YELLOW}${IS_CORE_NAME} 文件使用 > $IS_CORE_FILE${NONE}"
    }

    ##
    ## 本地目录安装脚本
    ##
    [[ $LOCAL_INSTALL ]] && {
        >$IS_SH_OK
        msg WARNING "${YELLOW}本地获取安装脚本 > $PWD ${NONE}"
    }

    timedatectl set-ntp true &>/dev/null
    [[ $? != 0 ]] && {
        msg WARNING "${YELLOW}\e[4m提醒!!! 无法设置自动同步时间, 可能会影响使用 VMess 协议.${NONE}"
    }

    ##
    ## [步骤 1/10] 准备安装环境
    ##
    msg WARNING "[步骤 1/10] 准备安装环境..."
    mkdir -p $TMPDIR
    [[ $IS_CORE_FILE ]] && {
        cp -f $IS_CORE_FILE $IS_CORE_OK
        msg OK "  - 使用自定义核心文件"
    }
    [[ $LOCAL_INSTALL ]] && {
        >$IS_SH_OK
        msg OK "  - 本地获取安装脚本"
    }
    msg OK "  - 安装环境准备完成"
    
    ##
    ## [步骤 2/10] 同步系统时间
    ##
    msg WARNING "[步骤 2/10] 同步系统时间..."
    timedatectl set-ntp true &>/dev/null
    [[ $? != 0 ]] && msg WARNING "  - 提醒：无法设置自动同步时间" || msg OK "  - 系统时间已同步"
    
    ##
    ## [步骤 3/10] 安装依赖包
    ##
    msg WARNING "[步骤 3/10] 安装依赖包..."
    install_pkg $IS_PKG &
    msg OK "  - 依赖包安装进行中 (后台)"

    ##
    ## [步骤 4/10] 检查 jq
    ##
    msg WARNING "[步骤 4/10] 检查 jq..."
    if [[ $(type -P jq) ]]; then
        >$IS_JQ_OK
        msg OK "  - jq 已安装"
    else
        JQ_NOT_FOUND=1
        msg WARNING "  - jq 未安装，将自动下载"
    fi
    
    ##
    ## [步骤 5/10] 下载必要文件
    ##
    msg WARNING "[步骤 5/10] 下载必要文件..."
    [[ $IS_WGET ]] && {
        [[ ! $IS_CORE_FILE ]] && { download core & msg OK "  - 开始下载 V2Ray 核心"; }
        [[ ! $LOCAL_INSTALL ]] && { download sh & msg OK "  - 开始下载脚本"; }
        [[ $JQ_NOT_FOUND ]] && { download jq & msg OK "  - 开始下载 jq"; }
        get_ip
        msg OK "  - 已获取服务器 IP"
    }

    ##
    ## [步骤 6/10] 等待下载完成
    ##
    msg WARNING "[步骤 6/10] 等待下载完成..."
    ##
    ## wait: 等待所有后台下载任务完成
    ## 前面步骤中，core、sh、jq 三个下载任务使用 & 在后台并行执行
    ## 这里需要等待所有文件下载完成后，才能进行后续的检查步骤
    ##
    ## 显示动态加载动画
    _loading=0
    _loading_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    while kill -0 $(jobs -p) 2>/dev/null; do
        printf "\r  - 下载进行中... %s" "${_loading_chars[$_loading]}"
        _loading=$(( (_loading + 1) % 10 ))
        sleep 0.1
    done
    printf "\r\033[K"
    wait
    msg OK "  - 所有文件下载完成"

    ##
    ## [步骤 7/10] 检查下载状态
    ##
    msg WARNING "[步骤 7/10] 检查下载状态..."
    check_status
    msg OK "  - 所有文件检查通过"

    ##
    ## [步骤 8/10] 测试核心文件
    ##
    msg WARNING "[步骤 8/10] 测试核心文件..."
    if [[ $IS_CORE_FILE ]]; then
        unzip -qo $IS_CORE_OK -d $TMPDIR/testzip &>/dev/null
        [[ $? != 0 ]] && {
            msg ERROR "  - 核心文件解压失败"
            exit_and_del_tmpdir
        }
        for i in ${IS_CORE} geoip.dat geosite.dat; do
            [[ ! -f $TMPDIR/testzip/$i ]] && IS_FILE_ERR=1 && break
        done
        [[ $IS_FILE_ERR ]] && {
            msg ERROR "  - 核心文件不完整"
            exit_and_del_tmpdir
        }
        msg OK "  - 核心文件测试通过"
    else
        msg OK "  - 使用官方核心文件"
    fi

    ##
    ## [步骤 9/10] 获取服务器 IP
    ##
    msg WARNING "[步骤 9/10] 获取服务器 IP..."
    [[ ! $IP ]] && {
        msg ERROR "  - 获取服务器 IP 失败"
        exit_and_del_tmpdir
    }
    msg OK "  - 服务器 IP: $IP"

    ##
    ## [步骤 10/10] 安装文件到系统
    ##
    msg WARNING "[步骤 10/10] 安装文件到系统..."
    
    ##
    ## 创建脚本目录
    ##
    mkdir -p $IS_SH_DIR

    ##
    ## 复制脚本文件
    ##
    if [[ $LOCAL_INSTALL ]]; then
        cp -rf $PWD/* $IS_SH_DIR
        msg OK "  - 已复制本地脚本"
    else
        unzip -qo $IS_SH_OK -d $IS_SH_DIR
        msg OK "  - 已解压脚本文件"
    fi

    ##
    ## 创建核心二进制目录
    ##
    mkdir -p $IS_CORE_DIR/bin
    msg OK "  - 已创建核心目录"
    
    ##
    ## 复制核心文件
    ##
    if [[ $IS_CORE_FILE ]]; then
        cp -rf $TMPDIR/testzip/* $IS_CORE_DIR/bin
        msg OK "  - 已复制核心文件到 $IS_CORE_DIR/bin"
    else
        unzip -qo $IS_CORE_OK -d $IS_CORE_DIR/bin
        msg OK "  - 已解压核心文件到 $IS_CORE_DIR/bin"
    fi

    ##
    ## 添加别名
    ##
    echo "alias $IS_CORE=$IS_SH_BIN" >>/root/.bashrc
    msg OK "  - 已添加别名 $IS_CORE -> $IS_SH_BIN"

    ##
    ## 核心命令
    ##
    ln -sf $IS_SH_DIR/$IS_CORE.sh $IS_SH_BIN
    msg OK "  - 已创建命令链接"

    ##
    ## jq 工具
    ##
    [[ $JQ_NOT_FOUND ]] && mv -f $IS_JQ_OK /usr/bin/jq && msg OK "  - 已安装 jq"

    ##
    ## 设置权限
    ##
    chmod +x $IS_CORE_BIN $IS_SH_BIN /usr/bin/jq
    msg OK "  - 已设置执行权限：$IS_CORE_BIN, $IS_SH_BIN, /usr/bin/jq (+x)"

    ##
    ## 创建日志目录
    ##
    mkdir -p $IS_LOG_DIR
    msg OK "  - 已创建日志目录：$IS_LOG_DIR (access.log, error.log)"

    ##
    ## 显示提示信息
    ##
    msg OK "生成配置文件..."

    ##
    ## 创建 systemd 服务
    ##
    load systemd.sh
    IS_NEW_INSTALL=1
    install_service $IS_CORE &>/dev/null

    ##
    ## 创建配置目录
    ##
    mkdir -p $IS_CONF_DIR

    ##
    ## TLS 方案选择
    ##
    if [[ ! $IS_INSTALL_CADDY && ! $IS_INSTALL_NGINX ]]; then
        
        ##
        ## 检测已安装的服务
        ##
        IS_CADDY_INSTALLED=
        IS_NGINX_INSTALLED=
        [[ -f /usr/local/bin/caddy || $(type -P caddy) ]] && IS_CADDY_INSTALLED=1
        [[ -f /usr/sbin/nginx || $(type -P nginx) ]] && IS_NGINX_INSTALLED=1
        
        echo
        echo -e "${YELLOW}选择 TLS 配置方案:${NONE}"
        
        ##
        ## 根据已安装的服务提供选项
        ##
        if [[ $IS_CADDY_INSTALLED && $IS_NGINX_INSTALLED ]]; then
            ##
            ## caddy 和 nginx 都已安装，提供更多选项
            ##
            echo "检测到 Caddy 和 Nginx 都已安装，请选择:"
            echo "1) 使用 Caddy"
            echo "2) 使用 Nginx"
            echo "3) 停止 Caddy，使用 Nginx"
            echo "4) 停止 Nginx，使用 Caddy"
            
            while :; do
                echo -ne "请输入选择 [1-4] (默认:2): "
                read TLS_CHOICE
                [[ ! $TLS_CHOICE ]] && TLS_CHOICE=2
                case $TLS_CHOICE in
                1)
                    IS_INSTALL_CADDY=1
                    break
                    ;;
                2)
                    IS_INSTALL_NGINX=1
                    break
                    ;;
                3)
                    msg WARNING "停止 Caddy..."
                    systemctl stop caddy &>/dev/null
                    systemctl disable caddy &>/dev/null
                    IS_INSTALL_NGINX=1
                    break
                    ;;
                4)
                    msg WARNING "停止 Nginx..."
                    systemctl stop nginx &>/dev/null
                    systemctl disable nginx &>/dev/null
                    IS_INSTALL_CADDY=1
                    break
                    ;;
                *)
                     echo "输入无效，请输入 1-4"
                    ;;
                esac
            done
        elif [[ $IS_CADDY_INSTALLED ]]; then
            ##
            ## 仅 caddy 已安装，提供选项
            ##
            echo "检测到 Caddy 已安装，请选择:"
            echo "1) 使用 Caddy (默认)"
            echo "2) 停止 Caddy，改用 Nginx"
            
            while :; do
                echo -ne "请输入选择 [1-2] (默认:1): "
                read TLS_CHOICE
                [[ ! $TLS_CHOICE ]] && TLS_CHOICE=1
                case $TLS_CHOICE in
                1)
                    IS_INSTALL_CADDY=1
                    break
                    ;;
                2)
                    msg WARNING "停止 Caddy..."
                    systemctl stop caddy &>/dev/null
                    systemctl disable caddy &>/dev/null
                    IS_INSTALL_NGINX=1
                    break
                    ;;
                *)
                     echo "输入无效，请输入 1-2"
                    ;;
                esac
            done
        elif [[ $IS_NGINX_INSTALLED ]]; then
            echo "检测到 Nginx 已安装，请选择:"
            echo "1) 使用 Nginx (默认)"
            echo "2) 停止 Nginx，改用 Caddy"
            
            while :; do
                echo -ne "请输入选择 [1-2] (默认:1): "
                read TLS_CHOICE
                [[ ! $TLS_CHOICE ]] && TLS_CHOICE=1
                case $TLS_CHOICE in
                1)
                    IS_INSTALL_NGINX=1
                    break
                    ;;
                2)
                    msg WARNING "停止 Nginx..."
                    systemctl stop nginx &>/dev/null
                    systemctl disable nginx &>/dev/null
                    IS_INSTALL_CADDY=1
                    break
                    ;;
                *)
                     echo "输入无效，请输入 1-2"
                    ;;
                esac
            done
        else
            ##
            ## 都没有安装，提供标准选项
            ##
            echo "1) Caddy (简洁，适合单站点)"
            echo "2) Nginx + Certbot (灵活，适合多站点共存) (默认)"
            
            while :; do
                echo -ne "请输入选择 [1-2] (默认:2): "
                read TLS_CHOICE
                [[ ! $TLS_CHOICE ]] && TLS_CHOICE=2
                case $TLS_CHOICE in
                1)
                    IS_INSTALL_CADDY=1
                    break
                    ;;
                2)
                    IS_INSTALL_NGINX=1
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
    
    ##
    ## 初始化 TLS 配置（Nginx 或 Caddy）
    ##
    if [[ $IS_INSTALL_NGINX ]]; then
        msg WARNING "初始化 Nginx 配置..."
        create nginx new
        
        ##
        ## 设置 is_nginx 标志，避免端口占用警告
        ##
        IS_NGINX=1
    elif [[ $IS_INSTALL_CADDY ]]; then
        msg WARNING "初始化 Caddy 配置..."
        create caddy new
        
        ##
        ## 设置 is_caddy 标志
        ##
        IS_CADDY=1
    fi

    ##
    ## 安装完成后引导用户配置第一个节点（与 v2ray add 完全一致）
    ##
    echo
    echo "=========================================="
    echo "    安装完成！现在配置第一个 V2Ray 节点"
    echo "=========================================="
    echo
    
    ##
    ## 显示所有协议选项（与 v2ray add 命令完全一致）
    ##
    echo "请选择协议类型:"
    for i in "${!PROTOCOL_LIST[@]}"; do
        NUM=$((i + 1))
        echo "$NUM) ${PROTOCOL_LIST[$i]}"
    done
    echo "$((${#PROTOCOL_LIST[@]} + 1))) 跳过，稍后手动配置"
    echo

    while :; do
        echo -ne "请输入选择 [1-$((${#PROTOCOL_LIST[@]} + 1))] (默认:1): "
        read PROTOCOL_CHOICE
        [[ ! $PROTOCOL_CHOICE ]] && PROTOCOL_CHOICE=1

        ##
        ## choice 应该 <= protocol list 长度
        ##
        if [[ $PROTOCOL_CHOICE -le ${#PROTOCOL_LIST[@]} ]]; then
            PROTOCOL_TYPE=${PROTOCOL_LIST[$((PROTOCOL_CHOICE - 1))]}
            break
        elif [[ $PROTOCOL_CHOICE -eq $((${#PROTOCOL_LIST[@]} + 1)) ]]; then
            msg OK "已跳过，安装后可以使用 'v2ray add' 命令添加配置"
            exit_and_del_tmpdir ok
        else
            echo "输入无效，请输入 1-$((${#PROTOCOL_LIST[@]} + 1))"
        fi
    done

    echo
    echo "请输入域名 (例如：v2ray.example.com):"
    read -p "> " DOMAIN_INPUT

    if [[ $DOMAIN_INPUT ]]; then
        echo
        msg WARNING "正在配置 ${YELLOW}$PROTOCOL_TYPE${NONE} > ${YELLOW}$DOMAIN_INPUT${NONE}..."
        # 根据协议类型传递参数
        # TLS 协议：add protocol host [uuid] [path]
        # 非 TLS 协议：add protocol auto auto auto host （auto 表示自动获取/随机）
        HOST=$DOMAIN_INPUT
        case $PROTOCOL_TYPE in
        *-TLS | *-tls)
            if ! add $PROTOCOL_TYPE $DOMAIN_INPUT; then
                msg ERROR "配置失败，请检查错误信息"
                exit_and_del_tmpdir error
            fi
            ;;
        *)
            if ! add $PROTOCOL_TYPE auto auto auto; then
                msg ERROR "配置失败，请检查错误信息"
                exit_and_del_tmpdir error
            fi
            ;;
        esac
        echo
        msg OK "配置完成！使用 'v2ray info' 查看配置信息"
    else
        msg WARNING "未输入域名，已跳过配置"
    fi

    # 删除临时目录并退出
    exit_and_del_tmpdir ok
}

# 开始执行
main $@
