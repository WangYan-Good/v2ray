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
        else
            # nginx.conf 已存在，检查是否需要添加 V2Ray 导入
            if ! grep -q "include $is_nginx_conf/\*.conf" $is_nginxfile; then
                # 备份原配置
                cp -f $is_nginxfile ${is_nginxfile}.bak.$(date +%Y%m%d%H%M%S)
                msg warn "检测到现有 Nginx 配置，已备份到 ${is_nginxfile}.bak.*"

                # 在 http 块中添加 V2Ray 导入（在 http 块的最后一个 } 之前）
                # 使用 awk 更可靠，避免 sed 转义问题
                local tmp_conf=$(mktemp)
                # 使用更健壮的正则表达式匹配 http 块
                awk -v inc="    include $is_nginx_conf/*.conf;" '
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
                ' $is_nginxfile > $tmp_conf

                if [[ $? -eq 0 ]]; then
                    mv -f $tmp_conf $is_nginxfile
                    if grep -q "include $is_nginx_conf/\*.conf" $is_nginxfile; then
                        msg ok "已添加 V2Ray 配置导入到 nginx.conf"
                    else
                        msg warn "无法自动添加 V2Ray 配置导入，请手动编辑 $is_nginxfile"
                        msg warn "添加：include $is_nginx_conf/*.conf;"
                    fi
                else
                    rm -f $tmp_conf
                    msg warn "无法自动添加 V2Ray 配置导入，请手动编辑 $is_nginxfile"
                    msg warn "添加：include $is_nginx_conf/*.conf;"
                fi
            fi
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
                    return 0
                    ;;
                3)
                    msg warn "请手动编辑：${is_nginx_site_file}"
                    return 0
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
    include ${is_nginx_site_file}.add;
}
"
        # 创建空的 .add 文件（避免 Nginx 启动失败）
        [[ ! -f ${is_nginx_site_file}.add ]] && echo "# 伪装网站配置" >${is_nginx_site_file}.add
        
        # 自动申请 Certbot 证书
        if ! nginx_certbot issue ${host}; then
            msg err "证书申请失败，已生成 Nginx 配置但无法启用 TLS"
            msg warn "你可以稍后手动申请证书：certbot certonly --webroot -w /var/www/certbot -d ${host}"
            return 1
        fi
        return 0
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

    include ${is_nginx_site_file}.add;
}
"
        # 创建空的 .add 文件（避免 Nginx 启动失败）
        [[ ! -f ${is_nginx_site_file}.add ]] && echo "# 伪装网站配置" >${is_nginx_site_file}.add
        
        # 自动申请 Certbot 证书
        if ! nginx_certbot issue ${host}; then
            msg err "证书申请失败，已生成 Nginx 配置但无法启用 TLS"
            msg warn "你可以稍后手动申请证书：certbot certonly --webroot -w /var/www/certbot -d ${host}"
            return 1
        fi
        return 0
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
                    return 0
                    ;;
                3)
                    msg warn "请手动编辑：${is_nginx_site_file}"
                    return 0
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

    include ${is_nginx_site_file}.add;
}
"
        # 创建空的 .add 文件（避免 Nginx 启动失败）
        [[ ! -f ${is_nginx_site_file}.add ]] && echo "# 伪装网站配置" >${is_nginx_site_file}.add
        
        # 自动申请 Certbot 证书
        if ! nginx_certbot issue ${host}; then
            msg err "证书申请失败，已生成 Nginx 配置但无法启用 TLS"
            msg warn "你可以稍后手动申请证书：certbot certonly --webroot -w /var/www/certbot -d ${host}"
            return 1
        fi
        return 0
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

        # 检查是否已有有效证书
        local cert_file="/etc/letsencrypt/live/${domain}/fullchain.pem"
        local has_valid_cert=false
        
        if [[ -f $cert_file ]]; then
            # 检查证书有效期
            local cert_expiry=$(openssl x509 -noout -enddate -in $cert_file 2>/dev/null | cut -d= -f2)
            if [[ $cert_expiry ]]; then
                local expiry_epoch=$(date -d "$cert_expiry" +%s 2>/dev/null)
                local now_epoch=$(date +%s)
                local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

                if [[ $days_left -gt 30 ]]; then
                    msg ok "证书已存在且有效，剩余 ${days_left} 天"
                    msg info "证书路径：${cert_file}"
                    msg info "过期时间：${cert_expiry}"
                    # 检查软链接是否存在
                    if [[ ! -L $is_nginx_dir/ssl/${domain} ]]; then
                        msg warn "证书软链接不存在，正在创建..."
                        mkdir -p $is_nginx_dir/ssl
                        ln -sf /etc/letsencrypt/live/${domain} $is_nginx_dir/ssl/${domain}
                        msg ok "软链接创建成功"
                    fi
                    # 启动或重载 Nginx
                    if pgrep -f "nginx: master" &>/dev/null; then
                        systemctl reload nginx &>/dev/null
                    else
                        systemctl start nginx &>/dev/null
                    fi
                    return 0
                else
                    msg warn "证书即将过期（剩余 ${days_left} 天），正在续期..."
                    has_valid_cert=true
                fi
            fi
        fi

        # 首次申请证书：使用 standalone 模式（不需要 Nginx 运行）
        # 续期证书：使用 webroot 模式（需要 Nginx 运行）
        if [[ $has_valid_cert == true ]]; then
            # 续期：使用 webroot 模式
            msg warn "Nginx 未运行，正在启动..."
            systemctl start nginx &>/dev/null
            sleep 2
            if ! pgrep -f "nginx: master" &>/dev/null; then
                msg err "Nginx 启动失败，无法申请证书"
                return 1
            fi
            msg ok "Nginx 已启动"

            # 测试 Nginx 配置并重载
            if ! nginx -t &>/dev/null; then
                msg err "Nginx 配置测试失败"
                nginx -t 2>&1 | tail -5
                return 1
            fi
            nginx -s reload &>/dev/null
            sleep 1

            # 验证挑战文件
            msg warn "验证 Nginx 配置..."
            local test_file="/var/www/certbot/.well-known/acme-challenge/test"
            mkdir -p "$(dirname $test_file)"
            echo "test" > $test_file
            sleep 1
            if ! curl -s --connect-timeout 3 "http://localhost/.well-known/acme-challenge/test" | grep -q "test"; then
                msg err "Nginx 配置验证失败：无法访问挑战文件"
                rm -f $test_file
                return 1
            fi
            rm -f $test_file
            msg ok "Nginx 配置验证通过"

            # 续期证书
            if certbot certonly --webroot \
                -w /var/www/certbot \
                -d ${domain} \
                --email admin@${domain} \
                --agree-tos \
                --non-interactive \
                --force-renewal \
                --key-type ecdsa 2>&1 | while IFS= read -r line; do
                    [[ $line ]] && msg info "  $line"
                done; then
                msg ok "证书续期成功"
                # 检查软链接是否存在
                if [[ ! -L $is_nginx_dir/ssl/${domain} ]]; then
                    msg warn "创建证书软链接..."
                    mkdir -p $is_nginx_dir/ssl
                    ln -sf /etc/letsencrypt/live/${domain} $is_nginx_dir/ssl/${domain}
                    msg ok "软链接创建成功"
                fi
                systemctl reload nginx &>/dev/null
                return 0
            else
                msg err "证书续期失败"
                return 1
            fi
        else
            # 首次申请：使用 standalone 模式
            msg warn "正在申请 SSL 证书（standalone 模式）..."
            
            # 确保 80 端口空闲
            systemctl stop nginx &>/dev/null
            sleep 1
            
            # 检查 80 端口是否被占用
            if ss -tlnp | grep -q ':80 '; then
                msg err "80 端口被占用，无法申请证书"
                ss -tlnp | grep ':80'
                msg warn "请关闭占用 80 端口的服务后重试"
                return 1
            fi

            # 申请证书
            if certbot certonly --standalone \
                -d ${domain} \
                --email admin@${domain} \
                --agree-tos \
                --non-interactive \
                --force-renewal \
                --key-type ecdsa 2>&1 | while IFS= read -r line; do
                    [[ $line ]] && msg info "  $line"
                done; then
                msg ok "证书申请成功"
                # 创建软链接到 Nginx 配置目录
                msg warn "创建证书软链接到 /etc/nginx/ssl/${domain}/..."
                mkdir -p $is_nginx_dir/ssl
                ln -sf /etc/letsencrypt/live/${domain} $is_nginx_dir/ssl/${domain}
                msg ok "软链接创建成功"
                # 启动 Nginx
                systemctl start nginx
                return 0
            else
                msg err "证书申请失败"
                msg warn "请检查:"
                msg "  1. 域名是否正确解析到服务器 IP"
                msg "  2. 防火墙是否开放 80 端口"
                msg "  3. 查看详细日志：tail -20 /var/log/letsencrypt/letsencrypt.log"
                return 1
            fi
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
        # 检查 Nginx 是否正在运行
        if pgrep -f "nginx: master" &>/dev/null; then
            # 运行中则重载
            $is_nginx_bin -s reload &>/dev/null
            return $?
        else
            # 未运行则启动
            msg warn "Nginx 未运行，正在启动..."
            systemctl start nginx &>/dev/null
            if pgrep -f "nginx: master" &>/dev/null; then
                msg ok "Nginx 启动成功"
                return 0
            else
                msg err "Nginx 启动失败，请检查配置"
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
