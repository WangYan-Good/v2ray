IS_DNS_LIST=(
    1.1.1.1
    8.8.8.8
    https://dns.google/dns-query
    https://cloudflare-dns.com/dns-query
    https://family.cloudflare-dns.com/dns-query
    set
    none
)
dns_set() {
    if [[ $1 ]]; then
        case ${1,,} in
        11 | 1111)
            IS_DNS_USE=${IS_DNS_LIST[0]}
            ;;
        88 | 8888)
            IS_DNS_USE=${IS_DNS_LIST[1]}
            ;;
        gg | google)
            IS_DNS_USE=${IS_DNS_LIST[2]}
            ;;
        cf | cloudflare)
            IS_DNS_USE=${IS_DNS_LIST[3]}
            ;;
        nosex | family)
            IS_DNS_USE=${IS_DNS_LIST[4]}
            ;;
        set)
            if [[ $2 ]]; then
                IS_DNS_USE=${2,,}
            else
                ask string IS_DNS_USE "请输入 DNS: "
            fi
            ;;
        none)
            IS_DNS_USE=none
            ;;
        *)
            err "无法识别 DNS 参数: $@"
            ;;
        esac
    else
        IS_TMP_LIST=(${IS_DNS_LIST[@]})
        ask list IS_DNS_USE null "\n请选择 DNS:\n"
        if [[ $IS_DNS_USE == "set" ]]; then
            ask string IS_DNS_USE "请输入 DNS: "
        fi
    fi
    if [[ $IS_DNS_USE == "none" ]]; then
        cat <<<$(jq '.dns={}' $IS_CONFIG_JSON) >$IS_CONFIG_JSON
    else
        cat <<<$(jq '.dns.servers=["'${IS_DNS_USE/https/https+local}'"]' $IS_CONFIG_JSON) >$IS_CONFIG_JSON
    fi
    manage restart &
    msg "\n已更新 DNS 为: $(_green $IS_DNS_USE)\n"
}