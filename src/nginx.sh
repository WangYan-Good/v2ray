#!/bin/bash

# Nginx + Certbot 自动 TLS 配置模块
# 支持多站点共存，共享 80/443 端口

nginx_config() {
    # 配置文件名包含协议名，如 VLESS-gRPC-TLS-proxy.yourdie.com.conf
    IS_NGINX_SITE_FILE=$IS_NGINX_CONF/${1}-${HOST}.conf
    IS_SSL_CERT=$IS_NGINX_DIR/ssl/${HOST}/fullchain.pem
    IS_SSL_KEY=$IS_NGINX_DIR/ssl/${HOST}/privkey.pem
    URL_PATH=${3:-}
    PORT=${4:-}

    case $1 in
    new)
        # 创建目录结构
        mkdir -p $IS_NGINX_DIR $IS_NGINX_DIR/ssl $IS_NGINX_CONF
        mkdir -p /var/log/nginx /var/www/certbot

        # 检查是否已有主配置
        if [[ ! -f $IS_NGINXFILE ]]; then
            cat >$IS_NGINXFILE <<EOF
# Nginx 主配置文件
# 由 V2Ray 脚本自动生成/管理
# 更多相关请阅读：https://wangyan-good.github.io/v2ray/nginx-auto-tls/

user root;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
    multi_accept on;
}

http {
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;

    # 导入 V2Ray 配置（自动 TLS 站点）
    include $IS_NGINX_CONF/*.conf;

    # 导入其他站点配置（用户自定义）
    include /etc/nginx/sites-enabled/*.conf;
}
EOF
        else
            # nginx.conf 已存在，检查是否需要添加 V2Ray 导入
            if ! grep -q "include $IS_NGINX_CONF/\*.conf" $IS_NGINXFILE; then
                # 备份原配置
                cp -f $IS_NGINXFILE ${IS_NGINXFILE}.bak.$(date +%Y%m%d%H%M%S)
                msg WARNING "检测到现有 Nginx 配置，已备份到 ${IS_NGINXFILE}.bak.*"

                # 在 http 块中添加 V2Ray 导入（在 http 块的最后一个 } 之前）
                # 使用 awk 更可靠，避免 sed 转义问题
                local TMP_CONF=$(mktemp)
                # 使用更健壮的正则表达式匹配 http 块
                awk -v inc="    include $IS_NGINX_CONF/*.conf;" '
                    # 匹配 http 块开始（允许行首空格，http 后空格，{ 前空格）
                    /^[[:space:]]*http[[:space:]]*\{/ {
                        in_http=1
                        print
                        next
                    }
                    # 在 http 块内的 } 前插入（允许行首空格）
                    in_http && /^[[:space:]]*\}[[:space:]]*$/ {
                        print "    # 导入 V2Ray 配置（自动 TLS 站点）"
                        print inc
                        print ""
                        print
                        in_http=0
                        next
                    }
                    # 打印其他行
                    {print}
                ' $IS_NGINXFILE > $TMP_CONF

                if [[ $? -eq 0 ]]; then
                    mv -f $TMP_CONF $IS_NGINXFILE
                    if grep -q "include $IS_NGINX_CONF/\*.conf" $IS_NGINXFILE; then
                        msg OK "已添加 V2Ray 配置导入到 nginx.conf"
                    else
                        msg WARNING "无法自动添加 V2Ray 配置导入，请手动编辑 $IS_NGINXFILE"
                        msg WARNING "添加：include $IS_NGINX_CONF/*.conf;"
                    fi
                else
                    rm -f $TMP_CONF
                    msg WARNING "无法自动添加 V2Ray 配置导入，请手动编辑 $IS_NGINXFILE"
                    msg WARNING "添加：include $IS_NGINX_CONF/*.conf;"
                fi
            fi
        fi
        ;;
    
    *ws*)
        # 检测配置冲突
        [[ -f ${IS_NGINX_SITE_FILE} ]] && {
            msg WARNING "检测到已存在的 Nginx 配置：${IS_NGINX_SITE_FILE}"
            msg WARNING "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read nginx_conf_choice
                [[ ! $NGINX_CONF_CHOICE ]] && NGINX_CONF_CHOICE=1
                case $NGINX_CONF_CHOICE in
                1)
                    cp -f ${IS_NGINX_SITE_FILE} ${IS_NGINX_SITE_FILE}.bak
                    msg OK "已备份现有配置：${IS_NGINX_SITE_FILE}.bak"
                    break
                    ;;
                2)
                    msg WARNING "跳过配置，保留现有配置"
                    return 0
                    ;;
                3)
                    msg WARNING "请手动编辑：${IS_NGINX_SITE_FILE}"
                    return 0
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        # WebSocket 配置 (VMess/VLESS/Trojan)
        cat >${IS_NGINX_SITE_FILE} <<<"
# ${HOST} - V2Ray WebSocket
# 由 V2Ray 脚本自动生成 - 请勿手动编辑

server {
    listen 80;
    listen [::]:80;
    server_name ${HOST};

    # ACME challenge for Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # HTTP 强制跳转 HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${HOST};

    # SSL 证书路径
    ssl_certificate ${IS_SSL_CERT};
    ssl_certificate_key ${IS_SSL_KEY};

    # SSL 会话优化
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # 现代 SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 1.1.1.1 8.8.8.8 valid=60s;
    resolver_timeout 2s;

    # HSTS (可选，生产环境建议启用)
    # add_header Strict-Transport-Security "max-age=63072000" always;

    # WebSocket 反向代理配置
    location ${URL_PATH} {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
        proxy_buffering off;
    }

    # 伪装网站配置 (可选)
    include ${IS_NGINX_SITE_FILE}.add;
}
"
        # 创建空的 .add 文件（避免 Nginx 启动失败）
        [[ ! -f ${IS_NGINX_SITE_FILE}.add ]] && echo "# 伪装网站配置" >${IS_NGINX_SITE_FILE}.add
        
        # 自动申请 Certbot 证书
        if ! nginx_certbot issue ${HOST}; then
            msg ERROR "证书申请失败，已生成 Nginx 配置但无法启用 TLS"
            msg WARNING "你可以稍后手动申请证书：certbot certonly --webroot -w /var/www/certbot -d ${HOST}"
            return 1
        fi
        return 0
        ;;

    *h2*)
        # 检测配置冲突
        [[ -f ${IS_NGINX_SITE_FILE} ]] && {
            msg WARNING "检测到已存在的 Nginx 配置：${IS_NGINX_SITE_FILE}"
            msg WARNING "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read nginx_conf_choice
                [[ ! $NGINX_CONF_CHOICE ]] && NGINX_CONF_CHOICE=1
                case $NGINX_CONF_CHOICE in
                1)
                    cp -f ${IS_NGINX_SITE_FILE} ${IS_NGINX_SITE_FILE}.bak
                    msg OK "已备份现有配置：${IS_NGINX_SITE_FILE}.bak"
                    break
                    ;;
                2)
                    msg WARNING "跳过配置，保留现有配置"
                    return
                    ;;
                3)
                    msg WARNING "请手动编辑：${IS_NGINX_SITE_FILE}"
                    return
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        # HTTP/2 配置
        cat >${IS_NGINX_SITE_FILE} <<<"
# ${HOST} - V2Ray HTTP/2
# 由 V2Ray 脚本自动生成 - 请勿手动编辑

server {
    listen 80;
    listen [::]:80;
    server_name ${HOST};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${HOST};

    ssl_certificate ${IS_SSL_CERT};
    ssl_certificate_key ${IS_SSL_KEY};

    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 1.1.1.1 8.8.8.8 valid=60s;
    resolver_timeout 2s;

    # H2 反向代理配置
    location ${URL_PATH} {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
    }

    include ${IS_NGINX_SITE_FILE}.add;
}
"
        # 创建空的 .add 文件（避免 Nginx 启动失败）
        [[ ! -f ${IS_NGINX_SITE_FILE}.add ]] && echo "# 伪装网站配置" >${IS_NGINX_SITE_FILE}.add
        
        # 自动申请 Certbot 证书
        if ! nginx_certbot issue ${HOST}; then
            msg ERROR "证书申请失败，已生成 Nginx 配置但无法启用 TLS"
            msg WARNING "你可以稍后手动申请证书：certbot certonly --webroot -w /var/www/certbot -d ${HOST}"
            return 1
        fi
        return 0
        ;;

    *grpc*)
        # 检测配置冲突
        [[ -f ${IS_NGINX_SITE_FILE} ]] && {
            msg WARNING "检测到已存在的 Nginx 配置：${IS_NGINX_SITE_FILE}"
            msg WARNING "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read nginx_conf_choice
                [[ ! $NGINX_CONF_CHOICE ]] && NGINX_CONF_CHOICE=1
                case $NGINX_CONF_CHOICE in
                1)
                    cp -f ${IS_NGINX_SITE_FILE} ${IS_NGINX_SITE_FILE}.bak
                    msg OK "已备份现有配置：${IS_NGINX_SITE_FILE}.bak"
                    break
                    ;;
                2)
                    msg WARNING "跳过配置，保留现有配置"
                    return 0
                    ;;
                3)
                    msg WARNING "请手动编辑：${IS_NGINX_SITE_FILE}"
                    return 0
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        # gRPC 配置
        cat >${IS_NGINX_SITE_FILE} <<<"
# ${HOST} - V2Ray gRPC
# 由 V2Ray 脚本自动生成 - 请勿手动编辑

server {
    listen 80;
    listen [::]:80;
    server_name ${HOST};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${HOST};

    ssl_certificate ${IS_SSL_CERT};
    ssl_certificate_key ${IS_SSL_KEY};

    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 1.1.1.1 8.8.8.8 valid=60s;
    resolver_timeout 2s;

    # gRPC 反向代理配置
    location /${URL_PATH}/ {
        grpc_pass grpc://127.0.0.1:${PORT};
        grpc_set_header Host \$host;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_read_timeout 300s;
    }

    include ${IS_NGINX_SITE_FILE}.add;
}
"
        # 创建空的 .add 文件（避免 Nginx 启动失败）
        [[ ! -f ${IS_NGINX_SITE_FILE}.add ]] && echo "# 伪装网站配置" >${IS_NGINX_SITE_FILE}.add
        
        # 自动申请 Certbot 证书
        if ! nginx_certbot issue ${HOST}; then
            msg ERROR "证书申请失败，已生成 Nginx 配置但无法启用 TLS"
            msg WARNING "你可以稍后手动申请证书：certbot certonly --webroot -w /var/www/certbot -d ${HOST}"
            return 1
        fi
        return 0
        ;;

    proxy)
        # 伪装网站配置（反向代理到目标网站）
        cat >${IS_NGINX_SITE_FILE}.add <<<"
    # 伪装网站 - 反向代理到 ${proxy_site}
    location / {
        proxy_pass https://${proxy_site};
        proxy_ssl_server_name on;
        proxy_set_header Host ${proxy_site};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_cache off;
    }
"
        ;;
    
    del)
        # 删除配置 - 遍历所有协议前缀的配置文件
        for conf in $IS_NGINX_CONF/*-${HOST}.conf $IS_NGINX_CONF/*-${HOST}.conf.add; do
            [[ -f $conf ]] && rm -f $conf
        done
        # 清理证书（可选，注释掉以保留证书）
        # rm -rf $IS_NGINX_DIR/ssl/${HOST}
        ;;
    esac
    
    # 创建空的 .add 文件（如果没有）
    if [[ $1 != "new" && $1 != 'proxy' && $1 != 'del' ]]; then
        [[ ! -f ${IS_NGINX_SITE_FILE}.add ]] && echo "# 伪装网站配置" >${IS_NGINX_SITE_FILE}.add
    fi
}

# 使用 Certbot 申请/续期证书
nginx_certbot() {
    local ACTION=$1
    local DOMAIN=$2

    # 检测 Certbot 版本，决定是否使用 --key-type ecdsa 参数
    # ECDSA 支持需要 Certbot >= 1.14.0 (2021 年发布)
    local CERTBOT_VERSION=$(certbot --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
    local CERTBOT_MAJOR=$(echo $CERTBOT_VERSION | cut -d. -f1)
    local CERTBOT_MINOR=$(echo $CERTBOT_VERSION | cut -d. -f2)
    local IS_ECDSA_SUPPORTED=0

    if [[ $CERTBOT_MAJOR -gt 1 ]] || [[ $CERTBOT_MAJOR -eq 1 && $CERTBOT_MINOR -ge 14 ]]; then
        IS_ECDSA_SUPPORTED=1
    fi

    case $ACTION in
    issue)
        # 申请证书
        msg WARNING "使用 Certbot 申请证书：${DOMAIN}"

        # 确保 webroot 目录存在
        mkdir -p /var/www/certbot

        # 检查是否已有有效证书
        local CERT_FILE="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
        local HAS_VALID_CERT=false

        if [[ -f $CERT_FILE ]]; then
            # 检查证书有效期
            local CERT_EXPIRY=$(openssl x509 -noout -enddate -in $CERT_FILE 2>/dev/null | cut -d= -f2)
            if [[ $CERT_EXPIRY ]]; then
                local EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s 2>/dev/null)
                local NOW_EPOCH=$(date +%s)
                local DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

                if [[ $DAYS_LEFT -gt 30 ]]; then
                    msg OK "证书已存在且有效，剩余 ${DAYS_LEFT} 天"
                    msg info "证书路径：${CERT_FILE}"
                    msg info "过期时间：${CERT_EXPIRY}"
                    # 检查软链接是否存在
                    if [[ ! -L $IS_NGINX_DIR/ssl/${DOMAIN} ]]; then
                        msg WARNING "证书软链接不存在，正在创建..."
                        mkdir -p $IS_NGINX_DIR/ssl
                        ln -sf /etc/letsencrypt/live/${DOMAIN} $IS_NGINX_DIR/ssl/${DOMAIN}
                        msg OK "软链接创建成功"
                    fi
                    # 启动或重载 Nginx
                    if pgrep -f "nginx: master" &>/dev/null; then
                        systemctl reload nginx &>/dev/null
                    else
                        systemctl start nginx &>/dev/null
                    fi
                    return 0
                else
                    msg WARNING "证书即将过期（剩余 ${days_left} 天），正在续期..."
                    HAS_VALID_CERT=true
                fi
            fi
        fi

        # 首次申请证书：使用 standalone 模式（不需要 Nginx 运行）
        # 续期证书：使用 webroot 模式（需要 Nginx 运行）
        if [[ $HAS_VALID_CERT == true ]]; then
            # 续期：使用 webroot 模式
            msg WARNING "Nginx 未运行，正在启动..."
            systemctl start nginx &>/dev/null
            sleep 2
            if ! pgrep -f "nginx: master" &>/dev/null; then
                msg ERROR "Nginx 启动失败，无法申请证书"
                return 1
            fi
            msg OK "Nginx 已启动"

            # 测试 Nginx 配置并重载
            if ! nginx -t &>/dev/null; then
                msg ERROR "Nginx 配置测试失败"
                nginx -t 2>&1 | tail -5
                return 1
            fi
            nginx -s reload &>/dev/null
            sleep 1

            # 验证挑战文件
            msg WARNING "验证 Nginx 配置..."
            local TEST_FILE="/var/www/certbot/.well-known/acme-challenge/test"
            mkdir -p "$(dirname $TEST_FILE)"
            echo "test" > $TEST_FILE
            sleep 1
            if ! curl -s --connect-timeout 3 "http://localhost/.well-known/acme-challenge/test" | grep -q "test"; then
                msg ERROR "Nginx 配置验证失败：无法访问挑战文件"
                rm -f $TEST_FILE
                return 1
            fi
            rm -f $TEST_FILE
            msg OK "Nginx 配置验证通过"

            # 续期证书（根据版本决定是否使用 ECDSA）
            local ECDSA_OPT=""
            [[ $IS_ECDSA_SUPPORTED -eq 1 ]] && ECDSA_OPT="--key-type ecdsa"

            if certbot certonly --webroot \
                -w /var/www/certbot \
                -d ${DOMAIN} \
                --email admin@${DOMAIN} \
                --agree-tos \
                --non-interactive \
                --force-renewal \
                $ECDSA_OPT 2>&1 | while IFS= read -r line; do
                    [[ $LINE ]] && msg info "  $LINE"
                done; then
                msg OK "证书续期成功"
                # 检查软链接是否存在
                if [[ ! -L $IS_NGINX_DIR/ssl/${DOMAIN} ]]; then
                    msg WARNING "创建证书软链接..."
                    mkdir -p $IS_NGINX_DIR/ssl
                    ln -sf /etc/letsencrypt/live/${DOMAIN} $IS_NGINX_DIR/ssl/${DOMAIN}
                    msg OK "软链接创建成功"
                fi
                systemctl reload nginx &>/dev/null
                return 0
            else
                msg ERROR "证书续期失败"
                return 1
            fi
        else
            # 首次申请：使用 standalone 模式
            msg WARNING "正在申请 SSL 证书（standalone 模式）..."
            
            # 确保 80 端口空闲
            systemctl stop nginx &>/dev/null
            sleep 1
            
            # 检查 80 端口是否被占用
            if ss -tlnp | grep -q ':80 '; then
                msg ERROR "80 端口被占用，无法申请证书"
                ss -tlnp | grep ':80'
                msg WARNING "请关闭占用 80 端口的服务后重试"
                return 1
            fi

            # 申请证书（根据版本决定是否使用 ECDSA）
            local ECDSA_OPT=""
            [[ $IS_ECDSA_SUPPORTED -eq 1 ]] && ECDSA_OPT="--key-type ecdsa"

            if certbot certonly --standalone \
                -d ${DOMAIN} \
                --email admin@${DOMAIN} \
                --agree-tos \
                --non-interactive \
                --force-renewal \
                $ECDSA_OPT 2>&1 | while IFS= read -r line; do
                    [[ $LINE ]] && msg info "  $LINE"
                done; then
                msg OK "证书申请成功"
                # 创建软链接到 Nginx 配置目录
                msg WARNING "创建证书软链接到 /etc/nginx/ssl/${DOMAIN}/..."
                mkdir -p $IS_NGINX_DIR/ssl
                ln -sf /etc/letsencrypt/live/${DOMAIN} $IS_NGINX_DIR/ssl/${DOMAIN}
                msg OK "软链接创建成功"
                # 启动 Nginx
                systemctl start nginx
                return 0
            else
                msg ERROR "证书申请失败"
                msg WARNING "请检查:"
                msg "  1. 域名是否正确解析到服务器 IP"
                msg "  2. 防火墙是否开放 80 端口"
                msg "  3. Certbot 版本是否过旧 (certbot --version)"
                msg "  4. 查看详细日志：tail -20 /var/log/letsencrypt/letsencrypt.log"
                return 1
            fi
        fi
        ;;

    renew)
        # 续期证书
        msg WARNING "续期证书..."
        certbot renew --quiet --deploy-hook "systemctl reload nginx"
        ;;

    esac
}

# 安装 Nginx + Certbot
install_nginx_certbot() {
    _green "\n安装 Nginx + Certbot 实现自动配置 TLS.\n"
    
    # 检查是否已安装
    if [[ -f $IS_NGINX_BIN ]]; then
        msg WARNING "Nginx 已安装，跳过安装"
        IS_NGINX=1
        return 0
    fi
    
    msg WARNING "安装 Nginx 和 Certbot..."
    
    if [[ $CMD =~ apt-get ]]; then
        # Ubuntu/Debian
        $CMD update -y &>/dev/null
        $CMD install nginx certbot python3-certbot-nginx -y &>/dev/null
    else
        # CentOS
        $CMD install epel-release -y &>/dev/null
        $CMD update -y &>/dev/null
        $CMD install nginx certbot python3-certbot-nginx -y &>/dev/null
    fi
    
    # 检查安装
    if [[ ! $(type -P nginx) ]]; then
        msg ERROR "Nginx 安装失败"
        return 1
    fi
    
    if [[ ! $(type -P certbot) ]]; then
        msg ERROR "Certbot 安装失败"
        return 1
    fi
    
    # 创建目录
    mkdir -p $IS_NGINX_DIR $IS_NGINX_CONF /var/www/certbot
    
    # 备份现有 nginx.conf（如果存在）
    if [[ -f $IS_NGINXFILE && ! -f ${IS_NGINXFILE}.bak ]]; then
        cp -f $IS_NGINXFILE ${IS_NGINXFILE}.bak
        msg WARNING "已备份现有 nginx.conf 到 ${IS_NGINXFILE}.bak"
    fi
    
    # 设置开机自启
    systemctl enable nginx &>/dev/null
    systemctl daemon-reload
    
    # 添加证书续期定时任务
    if [[ ! $(crontab -l 2>/dev/null | grep -q 'certbot renew') ]]; then
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'") | crontab -
        msg WARNING "已添加证书自动续期定时任务"
    fi

    IS_NGINX=1
    _green "安装 Nginx + Certbot 成功.\n"
}

# 测试 Nginx 配置
nginx_test() {
    if [[ -f $IS_NGINX_BIN ]]; then
        $IS_NGINX_BIN -t
        return $?
    fi
    return 1
}

# 重新加载 Nginx
nginx_reload() {
    if [[ -f $IS_NGINX_BIN ]]; then
        # 检查 Nginx 是否正在运行
        if pgrep -f "nginx: master" &>/dev/null; then
            # 运行中则重载
            $IS_NGINX_BIN -s reload &>/dev/null
            return $?
        else
            # 未运行则启动
            msg WARNING "Nginx 未运行，正在启动..."
            systemctl start nginx &>/dev/null
            if pgrep -f "nginx: master" &>/dev/null; then
                msg OK "Nginx 启动成功"
                return 0
            else
                msg ERROR "Nginx 启动失败，请检查配置"
                return 1
            fi
        fi
    fi
    return 1
}

# 重启 Nginx
nginx_restart() {
    systemctl restart nginx
    return $?
}
