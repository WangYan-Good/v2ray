#!/bin/bash
# install.sh - V2Ray 安装脚本 (已修复 ShellCheck 警告)

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
[[ $EUID != 0 ]] && err "当前非 ${YELLOW}ROOT 用户.${NONE}"

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
        echo -e "\n${YELLOW}WARNING${NONE} $*"
        ;;
    ERROR)
        echo -e "\n${RED}ERROR${NONE} $*"
        ;;
    *)
        echo -e "$*"
        ;;
    esac
}

##
## 显示帮助信息
##
show_help() {
    cat <<EOF
${IS_CORE_NAME} 安装脚本

用法：$0 [选项]

选项:
  -f, --core-file FILE      使用本地核心文件
  -l, --local-install       本地安装模式
  -p, --proxy PROXY         使用代理 (例如：http://127.0.0.1:2333)
  -v, --core-version VER    指定核心版本 (例如：v5.0.0)
  --tls SCHEME              安装 TLS (caddy 或 nginx)
  -h, --help                显示此帮助信息

示例:
  $0                        # 默认安装
  $0 -p http://127.0.0.1:7890  # 使用代理安装
  $0 --tls caddy            # 安装时配置 Caddy TLS
  $0 -v v5.0.0              # 安装指定版本

EOF
    exit 0
}

##
## 检查依赖包
##
check_pkg() {
    local CMD_NOT_FOUND=""
    
    for i in "$@"; do
        if [[ ! $(type -P "$i") ]]; then
            CMD_NOT_FOUND="$CMD_NOT_FOUND,$i"
        fi
    done
    
    [[ $CMD_NOT_FOUND ]] && {
        ## 将逗号分隔的列表转换为空格分隔的包名列表
        ##
        PKG="${CMD_NOT_FOUND#,}"
        PKG="${PKG//,/ }"
        msg WARNING "安装依赖包 >${PKG}"
        
        ##
        ## 第一次尝试安装
        ##
        if $CMD install -y $PKG &>/dev/null; then
            touch "$IS_PKG_OK"
        else
            ##
            ## 如果第一次安装失败，尝试修复后再次安装
            ## 针对 CentOS 系统：先安装 epel-release 源，然后更新系统
            ##
            [[ $CMD =~ yum ]] && yum install epel-release -y &>/dev/null
            $CMD update -y &>/dev/null
            if $CMD install -y $PKG &>/dev/null; then
                touch "$IS_PKG_OK"
            fi
        fi
    } || touch "$IS_PKG_OK"
}

##
## 下载文件
##
download() {
    local LINK=""
    local NAME=""
    local TMPFILE=""
    local IS_OK=""
    
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
    ## jq is a lightweight and flexible command-line JSON processor
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
    [[ ! -f "$IS_PKG_OK" ]] && {
        msg ERROR "安装依赖包失败"
        msg ERROR "请尝试手动安装依赖包：$CMD update -y; $CMD install -y $IS_PKG"
        IS_FAIL=1
    }

    ##
    ## 下载文件状态
    ##
    if [[ $IS_WGET ]]; then
        [[ ! -f "$IS_CORE_OK" ]] && {
            msg ERROR "下载 ${IS_CORE_NAME} 失败"
            IS_FAIL=1
        }
        [[ ! -f "$IS_SH_OK" ]] && {
            msg ERROR "下载 ${IS_CORE_NAME} 脚本失败"
            IS_FAIL=1
        }
        [[ ! -f "$IS_JQ_OK" ]] && {
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
            err "如果想要安装旧版本，请转到：https://github.com/WangYan-Good/v2ray/tree/old"
            ;;
        -f | --core-file)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数，正确使用示例：[$1 /root/$IS_CORE-linux-64.zip]"
            } || [[ ! -f $2 ]] && {
                err "($2) 不是一个常规的文件."
            }
            IS_CORE_FILE=$2
            shift 2
            ;;
        -l | --local-install)
            [[ ! -f "${PWD}/src/core.sh" || ! -f "${PWD}/$IS_CORE.sh" ]] && {
                err "当前目录 (${PWD}) 非完整的脚本目录."
            }
            LOCAL_INSTALL=1
            shift 1
            ;;
        -p | --proxy)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数，正确使用示例：[$1 http://127.0.0.1:2333 or -p SOCKS5://127.0.0.1:2333]"
            }
            PROXY=$2
            shift 2
            ;;
        -v | --core-version)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数，正确使用示例：[$1 v1.8.1]"
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
            echo -e "\n${IS_ERR} ($*) 为未知参数...\n"
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
    rm -rf "$TMPDIR"
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
    if [[ -f "${PWD}/src/core.sh" && -f "${PWD}/v2ray.sh" ]]; then
        msg WARNING "检测到本地脚本，使用本地安装模式"
        LOCAL_INSTALL=1
    fi

    ##
    ## 2.检查旧版本
    ##
    [[ -f "$IS_SH_BIN" && -d "$IS_CORE_DIR/bin" && -d "$IS_SH_DIR" && -d "$IS_CONF_DIR" ]] && {
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
            read -r REINSTALL_CHOICE
            [[ ! $REINSTALL_CHOICE ]] && REINSTALL_CHOICE=3
            case $REINSTALL_CHOICE in
            1)
                msg WARNING "执行重新安装..."
                break
                ;;
            2)
                msg WARNING "执行卸载后重新安装..."
                break
                ;;
            3)
                exit_and_del_tmpdir "用户取消安装"
                ;;
            *)
                msg ERROR "无效的选择，请输入 1-3"
                ;;
            esac
        done
    }

    ##
    ## 3.解析参数
    ##
    [[ $# -gt 0 ]] && pass_args "$@"

    ##
    ## 4.创建临时目录
    ##
    mkdir -p "$TMPDIR"

    ##
    ## 5.检查并使用本地核心文件
    ##
    [[ $IS_CORE_FILE ]] && {
        msg WARNING "使用本地核心文件：$IS_CORE_FILE"
        cp -f "$IS_CORE_FILE" "$IS_CORE_OK"
    }

    ##
    ## 6.检查并使用本地脚本
    ##
    [[ $LOCAL_INSTALL ]] && {
        msg WARNING "使用本地脚本安装"
        mkdir -p "$IS_SH_OK"
        cp -rf "${PWD}/src" "$IS_SH_OK/"
        cp -rf "${PWD}/$IS_CORE.sh" "$IS_SH_OK/"
        touch "$IS_SH_OK"
    }

    ##
    ## 7.检查依赖
    ##
    IS_PKG="$IS_PKG jq"
    check_pkg $IS_PKG || {
        msg ERROR "检查依赖失败"
        exit 1
    }

    ##
    ## 8.检查 jq 是否存在
    ##
    [[ ! $(type -P jq) ]] && JQ_NOT_FOUND=1

    ##
    ## 9.下载文件并获取 IP
    ##
    if [[ ! $IS_WGET ]]; then
        IS_WGET=1
        [[ ! $IS_CORE_FILE ]] && download core &
        [[ ! $LOCAL_INSTALL ]] && download sh &
        [[ $JQ_NOT_FOUND ]] && download jq &
        get_ip
        wait
        check_status
    fi

    ##
    ## 10.安装核心
    ##
    msg INFO "开始安装 ${IS_CORE_NAME}..."
    
    ## 创建目录
    mkdir -p "$IS_CORE_DIR"
    mkdir -p "$IS_CONF_DIR"
    mkdir -p "$IS_LOG_DIR"

    ## 解压核心
    if [[ -f "$IS_CORE_OK" ]]; then
        unzip -o "$IS_CORE_OK" -d "$TMPDIR" &>/dev/null
        mkdir -p "$IS_CORE_DIR/bin"
        mv -f "$TMPDIR/$IS_CORE" "$IS_CORE_BIN"
        chmod +x "$IS_CORE_BIN"
    fi

    ## 安装 jq
    if [[ -f "$IS_JQ_OK" ]]; then
        mv -f "$IS_JQ_OK" /usr/local/bin/jq
        chmod +x /usr/local/bin/jq
    fi

    ## 安装脚本
    if [[ -f "$IS_SH_OK" ]]; then
        mkdir -p "$IS_SH_DIR"
        if [[ -d "$IS_SH_OK" ]]; then
            cp -rf "$IS_SH_OK"/* "$IS_SH_DIR/"
        else
            unzip -o "$IS_SH_OK" -d "$IS_SH_DIR" &>/dev/null
        fi
        chmod +x "$IS_SH_DIR"/*.sh
        ln -sf "$IS_SH_DIR/$IS_CORE.sh" "$IS_SH_BIN"
    fi

    ##
    ## 11.清理临时目录
    ##
    exit_and_del_tmpdir "安装完成"
}

# 执行主函数
main "$@"
