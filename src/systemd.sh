##
## 安装前系统级配置: 文件描述符限制
## 确保系统能支持大量并发连接
##
setup_system_limits() {
    local limits_conf="/etc/security/limits.conf"

    ##
    ## 1. 设置系统级文件描述符上限 (/etc/security/limits.conf)
    ##
    if ! grep -q 'xray.*nofile' "$limits_conf" 2>/dev/null; then
        cat >>"$limits_conf" <<'EOF'

# Xray 文件描述符限制
root soft nofile 1048576
root hard nofile 1048576
* soft nofile 1048576
* hard nofile 1048576
EOF
    fi

    ##
    ## 2. 设置系统全局文件描述符上限 (fs.file-max)
    ##
    local current_max
    current_max=$(sysctl -n fs.file-max 2>/dev/null || echo "0")
    if [[ "$current_max" != "0" ]] && [[ "$current_max" -lt 1048576 ]]; then
        if [[ ! -f /etc/sysctl.d/99-xray.conf ]] || ! grep -q 'fs.file-max' /etc/sysctl.d/99-xray.conf 2>/dev/null; then
            # 追加到 Xray sysctl 配置或创建新文件
            if [[ -f /etc/sysctl.d/99-xray.conf ]]; then
                echo "fs.file-max = 1048576" >>/etc/sysctl.d/99-xray.conf
            else
                echo "fs.file-max = 1048576" >/etc/sysctl.d/99-xray.conf
            fi
        fi
    fi

    ##
    ## 3. 设置 systemd 全局默认限制
    ##
    local systemd_conf="/etc/systemd/system.conf"
    if [[ -f "$systemd_conf" ]] && ! grep -q 'DefaultLimitNOFILE=' "$systemd_conf" 2>/dev/null; then
        sed -i 's/^#*DefaultLimitNOFILE=.*/DefaultLimitNOFILE=1048576/' "$systemd_conf"
        # 如果原本没有该配置（sed 未匹配到），则添加
        if ! grep -q 'DefaultLimitNOFILE=1048576' "$systemd_conf" 2>/dev/null; then
            echo "DefaultLimitNOFILE=1048576" >>"$systemd_conf"
        fi
    fi
}

install_service() {
    case $1 in
    xray)
        is_doc_site=https://xtls.github.io/
        cat >/lib/systemd/system/$is_core.service <<<"
[Unit]
Description=$is_core_name Service
Documentation=$is_doc_site
After=network.target nss-lookup.target

[Service]
#User=nobody
User=root
NoNewPrivileges=true
ExecStart=$is_core_bin run -config $is_config_json -confdir $is_conf_dir
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
#AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target"
        ;;
    caddy)
        cat >/lib/systemd/system/caddy.service <<<"
#https://github.com/caddyserver/dist/blob/master/init/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=$is_caddy_bin run --environ --config $is_caddy_file --adapter caddyfile
ExecReload=$is_caddy_bin reload --config $is_caddy_file --adapter caddyfile
TimeoutStopSec=5s
LimitNPROC=10000
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
#AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target"
        ;;
    nginx)
        cat >/lib/systemd/system/nginx.service <<<"
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true
LimitNPROC=10000
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target"
        ;;
    esac

    # enable, reload
    systemctl enable $1
    systemctl daemon-reload
}
