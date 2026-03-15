# show help msg
show_help() {
    echo -e "Usage: $0 [-f xxx | -l | -p xxx | -v xxx | --tls xxx | -h]"
    echo -e "  -f, --core-file <path>          自定义 $is_core_name 文件路径，e.g., -f /root/${is_core}-linux-64.zip"
    echo -e "  -l, --local-install             本地获取安装脚本，使用当前目录"
    echo -e "  -p, --proxy <addr>              使用代理下载，e.g., -p http://127.0.0.1:2333"
    echo -e "  -v, --core-version <ver>        自定义 $is_core_name 版本，e.g., -v v5.4.1"
    echo -e "  --tls <caddy|nginx>             选择 TLS 方案，e.g., --tls nginx"
    echo -e "  -h, --help                      显示此帮助界面\n"

    exit 0
}
