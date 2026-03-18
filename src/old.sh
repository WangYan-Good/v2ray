IS_OLD_LIST=(
	TCP
	TCP_HTTP
	WebSocket
	"WebSocket + TLS"
	HTTP/2
	mKCP
	mKCP_utp
	mKCP_srtp
	mKCP_wechat-video
	mKCP_dtls
	mKCP_wireguard
	QUIC
	QUIC_utp
	QUIC_srtp
	QUIC_wechat-video
	QUIC_dtls
	QUIC_wireguard
	TCP_dynamicPort
	TCP_HTTP_dynamicPort
	WebSocket_dynamicPort
	mKCP_dynamicPort
	mKCP_utp_dynamicPort
	mKCP_srtp_dynamicPort
	mKCP_wechat-video_dynamicPort
	mKCP_dtls_dynamicPort
	mKCP_wireguard_dynamicPort
	QUIC_dynamicPort
	QUIC_utp_dynamicPort
	QUIC_srtp_dynamicPort
	QUIC_wechat-video_dynamicPort
	QUIC_dtls_dynamicPort
	QUIC_wireguard_dynamicPort
	VLESS_WebSocket_TLS
)

# del old file
del_old_file() {
	# old sh bin
	_V2RAY_SH="/usr/local/sbin/v2ray"
	rm -rf $_V2RAY_SH $IS_OLD_CONF $IS_OLD_DIR $IS_CORE_DIR/233blog_v2ray_config.json /usr/bin/v2ray
	# del alias
	sed -i "#$_V2RAY_SH#d" /root/.bashrc
	exit
}

# read old config
. $IS_OLD_CONF
IS_OLD=${IS_OLD_LIST[$V2RAY_TRANSPORT - 1]}
case $V2RAY_TRANSPORT in
3 | 20)
	IS_OLD_USE=
	;;
4)
	IS_OLD_USE=ws
	;;
5)
	IS_OLD_USE=h2
	;;
33)
	IS_OLD_USE=vws
	;;
*)
	IS_TEST_OLD_USE=($(sed 's/_dynamicPort//;s/_/ /' <<<$IS_OLD))
	IS_OLD_USE=${IS_TEST_OLD_USE[0]#m}
	IS_OLD_HEADER_TYPE=${IS_TEST_OLD_USE[1]}
	[[ ! $IS_OLD_HEADER_TYPE ]] && IS_OLD_HEADER_TYPE=none
	;;
esac

if [[ $IS_OLD_USE && ! $IS_OLD_HEADER_TYPE ]]; then
	# not use caddy auto tls
	[[ ! $CADDY ]] && IS_OLD_USE=
fi

# add old config
if [[ $IS_OLD_USE ]]; then
	IS_TMP_LIST=("删除旧配置" "恢复: $IS_OLD")

	ask list is_do_upgrade null "\n是否恢复旧配置:\n"

	[[ $REPLY == '1' ]] && {
		_green "\n删除完成!\n"
		del_old_file
	}

	_green "\n开始恢复...\n"

	# upgrade caddy
	if [[ $CADDY ]]; then
		get install-caddy
		# bak caddy files
		mv -f $IS_CADDYFILE $IS_CADDYFILE.233.bak
		mv -f $IS_CADDY_DIR/sites $IS_CADDY_DIR/sites.233.bak
		load caddy.sh
		caddy_config new
	fi
	IS_CHANGE=1
	IS_DONT_AUTO_EXIT=1
	IS_DONT_SHOW_INFO=1
	if [[ $SHADOWSOCKS ]]; then
		for v in ${SS_METHOD_LIST[@]}; do
			[[ $(grep -E -i "^${SSCIPHERS}$" <<<$v) ]] && SS_METHOD=$v && break
		done
		if [[ $SS_METHOD ]]; then
			add ss $SS_PORT $SS_PASS $SS_METHOD
		fi
	fi
	if [[ $SOCKS ]]; then
		add socks $SOCKS_PORT $SOCKS_USERNAME $SOCKS_USERPASS
	fi
	PORT=$V2RAY_PORT
	UUID=$V2RAY_ID
	IS_NO_KCP_SEED=1
	HEADER_TYPE=$IS_OLD_HEADER_TYPE
	[[ $CADDY ]] && HOST=$DOMAIN
	PATH=/$PATH
	[[ ! $PATH_STATUS ]] && PATH=
	if [[ $(grep dynamic <<<$IS_OLD) ]]; then
		IS_DYNAMIC_PORT=1
		IS_DYNAMIC_PORT_RANGE="$V2RAY_DYNAMICPORT_START-$V2RAY_DYNAMICPORT_END"
		add ${IS_OLD_USE}d
	else
		add $IS_OLD_USE
	fi

	if [[ $path_status ]]; then
		change $IS_CONFIG_NAME web $PROXY_SITE
	fi
	IS_DONT_AUTO_EXIT=
	IS_DONT_SHOW_INFO=
	[[ $IS_API_FAIL ]] && manage restart &
	[[ $CADDY ]] && manage restart caddy
	info $IS_CONFIG_NAME
else
	ask string y "是否删除旧配置? [y]:"
	_green "\n删除完成!\n"
fi

del_old_file