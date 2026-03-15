#!/bin/bash

# Nginx + Certbot 自动 TLS 配置模块
# 支持多站点共存，共享 80/443 端口

nginx_config() {
    is_nginx_site_file=$is_nginx_conf/${host}.conf
    is_ssl_cert=$is_nginx_dir/ssl/${host}/fullchain.pem
    is_ssl_key=$is_nginx_dir/ssl/${host}/privkey.pem
    
    case $1 in
    new)
        # 创建目录结构
        mkdir -p $is_nginx_dir $is_nginx_dir/ssl $is_nginx_conf
        mkdir -p /var/log/nginx /var/www/certbot
        
        # 检查是否已有主配置
        if [[ ! -f $is_nginxfile ]]; then
            cat >$is_nginxfile <<EOF
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
    include $is_nginx_conf/*.conf;
    
    # 导入其他站点配置（用户自定义）
    include /etc/nginx/sites-enabled/*.conf;
}
EOF
        fi
        ;;
    
    *ws*)
        # 检测配置冲突
        [[ -f ${is_nginx_site_file} ]] && {
            msg warn "检测到已存在的 Nginx 配置：${is_nginx_site_file}"
            msg warn "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read nginx_conf_choice
                [[ ! $nginx_conf_choice ]] && nginx_conf_choice=1
                case $nginx_conf_choice in
                1)
                    cp -f ${is_nginx_site_file} ${is_nginx_site_file}.bak
                    msg ok "已备份现有配置：${is_nginx_site_file}.bak"
                    break
                    ;;
                2)
                    msg warn "跳过配置，保留现有配置"
                    return
                    ;;
                3)
                    msg warn "请手动编辑：${is_nginx_site_file}"
                    return
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        # WebSocket 配置 (VMess/VLESS/Trojan)
        cat >${is_nginx_site_file} <<<"
# ${host} - V2Ray WebSocket
# 由 V2Ray 脚本自动生成 - 请勿手动编辑

server {
    listen 80;
    listen [::]:80;
    server_name ${host};

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
    server_name ${host};

    # SSL 证书路径
    ssl_certificate ${is_ssl_cert};
    ssl_certificate_key ${is_ssl_key};

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
    location ${path} {
        proxy_pass http://127.0.0.1:${port};
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
    import ${is_nginx_site_file}.add
}
"
        # 自动申请 Certbot 证书
        nginx_certbot issue ${host}
        ;;
    
    *h2*)
        # 检测配置冲突
        [[ -f ${is_nginx_site_file} ]] && {
            msg warn "检测到已存在的 Nginx 配置：${is_nginx_site_file}"
            msg warn "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read nginx_conf_choice
                [[ ! $nginx_conf_choice ]] && nginx_conf_choice=1
                case $nginx_conf_choice in
                1)
                    cp -f ${is_nginx_site_file} ${is_nginx_site_file}.bak
                    msg ok "已备份现有配置：${is_nginx_site_file}.bak"
                    break
                    ;;
                2)
                    msg warn "跳过配置，保留现有配置"
                    return
                    ;;
                3)
                    msg warn "请手动编辑：${is_nginx_site_file}"
                    return
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        # HTTP/2 配置
        cat >${is_nginx_site_file} <<<"
# ${host} - V2Ray HTTP/2
# 由 V2Ray 脚本自动生成 - 请勿手动编辑

server {
    listen 80;
    listen [::]:80;
    server_name ${host};

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
    server_name ${host};

    ssl_certificate ${is_ssl_cert};
    ssl_certificate_key ${is_ssl_key};

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
    location ${path} {
        proxy_pass http://127.0.0.1:${port};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
    }

    import ${is_nginx_site_file}.add
}
"
        # 自动申请 Certbot 证书
        nginx_certbot issue ${host}
        ;;
    
    *grpc*)
        # 检测配置冲突
        [[ -f ${is_nginx_site_file} ]] && {
            msg warn "检测到已存在的 Nginx 配置：${is_nginx_site_file}"
            msg warn "请选择:"
            msg "1) 覆盖现有配置 (备份为 .bak)"
            msg "2) 跳过，保留现有配置"
            msg "3) 修改配置 (手动编辑)"
            while :; do
                echo -ne "请输入选择 [1-3] (默认:1): "
                read nginx_conf_choice
                [[ ! $nginx_conf_choice ]] && nginx_conf_choice=1
                case $nginx_conf_choice in
                1)
                    cp -f ${is_nginx_site_file} ${is_nginx_site_file}.bak
                    msg ok "已备份现有配置：${is_nginx_site_file}.bak"
                    break
                    ;;
                2)
                    msg warn "跳过配置，保留现有配置"
                    return
                    ;;
                3)
                    msg warn "请手动编辑：${is_nginx_site_file}"
                    return
                    ;;
                *)
                    msg "输入无效，请输入 1-3"
                    ;;
                esac
            done
        }
        # gRPC 配置
        cat >${is_nginx_site_file} <<<"
# ${host} - V2Ray gRPC
# 由 V2Ray 脚本自动生成 - 请勿手动编辑

server {
    listen 80;
    listen [::]:80;
    server_name ${host};

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
    server_name ${host};

    ssl_certificate ${is_ssl_cert};
    ssl_certificate_key ${is_ssl_key};

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
    location /${path}/ {
        grpc_pass grpc://127.0.0.1:${port};
        grpc_set_header Host \$host;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_read_timeout 300s;
    }

    import ${is_nginx_site_file}.add
}
"
        # 自动申请 Certbot 证书
        nginx_certbot issue ${host}
        ;;
    
    proxy)
        # 伪装网站配置（反向代理到目标网站）
        cat >${is_nginx_site_file}.add <<<"
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
        # 删除配置
        rm -rf ${is_nginx_site_file} ${is_nginx_site_file}.add
        # 清理证书（可选，注释掉以保留证书）
        # rm -rf $is_nginx_dir/ssl/${host}
        ;;
    esac
    
    # 创建空的 .add 文件（如果没有）
    if [[ $1 != "new" && $1 != 'proxy' && $1 != 'del' ]]; then
        [[ ! -f ${is_nginx_site_file}.add ]] && echo "# 伪装网站配置" >${is_nginx_site_file}.add
    fi
}

# 使用 Certbot 申请/续期证书
nginx_certbot() {
    local action=$1
    local domain=$2
    
    case $action in
    issue)
        # 申请证书
        msg warn "使用 Certbot 申请证书：${domain}"
        
        # 确保 webroot 目录存在
        mkdir -p /var/www/certbot
        
        # 使用 webroot 模式申请（不影响现有服务）
        certbot certonly --webroot \
            -w /var/www/certbot \
            -d ${domain} \
            --email admin@${domain} \
            --agree-tos \
            --non-interactive \
            --force-renewal \
            --key-type ecdsa
        
        local cert_status=$?
        
        if [[ $cert_status -eq 0 ]]; then
            msg ok "证书申请成功"
            # 重新加载 Nginx
            systemctl reload nginx &>/dev/null
            return 0
        else
            msg err "证书申请失败"
            return 1
        fi
        ;;
    
    renew)
        # 续期证书
        msg warn "续期证书..."
        certbot renew --quiet --deploy-hook "systemctl reload nginx"
        ;;
    
    esac
}

# 安装 Nginx + Certbot
install_nginx_certbot() {
    _green "\n安装 Nginx + Certbot 实现自动配置 TLS.\n"
    
    # 检查是否已安装
    if [[ -f $is_nginx_bin ]]; then
        msg warn "Nginx 已安装，跳过安装"
        is_nginx=1
        return 0
    fi
    
    msg warn "安装 Nginx 和 Certbot..."
    
    if [[ $cmd =~ apt-get ]]; then
        # Ubuntu/Debian
        $cmd update -y &>/dev/null
        $cmd install nginx certbot python3-certbot-nginx -y &>/dev/null
    else
        # CentOS
        $cmd install epel-release -y &>/dev/null
        $cmd update -y &>/dev/null
        $cmd install nginx certbot python3-certbot-nginx -y &>/dev/null
    fi
    
    # 检查安装
    if [[ ! $(type -P nginx) ]]; then
        msg err "Nginx 安装失败"
        return 1
    fi
    
    if [[ ! $(type -P certbot) ]]; then
        msg err "Certbot 安装失败"
        return 1
    fi
    
    # 创建目录
    mkdir -p $is_nginx_dir $is_nginx_conf /var/www/certbot
    
    # 备份现有 nginx.conf（如果存在）
    if [[ -f $is_nginxfile && ! -f ${is_nginxfile}.bak ]]; then
        cp -f $is_nginxfile ${is_nginxfile}.bak
        msg warn "已备份现有 nginx.conf 到 ${is_nginxfile}.bak"
    fi
    
    # 设置开机自启
    systemctl enable nginx &>/dev/null
    systemctl daemon-reload
    
    # 添加证书续期定时任务
    if [[ ! $(crontab -l 2>/dev/null | grep -q 'certbot renew') ]]; then
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'") | crontab -
        msg warn "已添加证书自动续期定时任务"
    fi
    
    is_nginx=1
    _green "安装 Nginx + Certbot 成功.\n"
}

# 测试 Nginx 配置
nginx_test() {
    if [[ -f $is_nginx_bin ]]; then
        $is_nginx_bin -t
        return $?
    fi
    return 1
}

# 重新加载 Nginx
nginx_reload() {
    if [[ -f $is_nginx_bin ]]; then
        $is_nginx_bin -s reload
        return $?
    fi
    return 1
}

# 重启 Nginx
nginx_restart() {
    systemctl restart nginx
    return $?
}
