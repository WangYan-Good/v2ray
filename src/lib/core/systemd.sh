install_service() {
    case $1 in
    xray | v2ray)
        IS_DOC_SITE=https://xtls.github.io/
        [[ $1 == 'v2ray' ]] && IS_DOC_SITE=https://www.v2fly.org/
        cat >/lib/systemd/system/$IS_CORE.service <<<"
[Unit]
Description=$IS_CORE_NAME Service
Documentation=$IS_DOC_SITE
After=network.target nss-lookup.target

[Service]
#User=nobody
User=root
NoNewPrivileges=true
ExecStart=$IS_CORE_BIN run -config $IS_CONFIG_JSON -confdir $IS_CONF_DIR
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
ExecStart=$IS_CADDY_BIN run --environ --config $IS_CADDYFILE --adapter caddyfile
ExecReload=$IS_CADDY_BIN reload --config $IS_CADDYFILE --adapter caddyfile
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
