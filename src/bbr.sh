#!/bin/bash

##
## 内核参数优化模块
## - BBR / BBRv2 拥塞控制
## - TCP 连接优化
## - 文件描述符系统级配置
## - 内存与网络缓冲优化
##

_err() {
    echo -e "\e[31m错误! $*\e[0m\n"
}

_green() {
    echo -e "\e[92m$*\e[0m"
}

_yellow() {
    echo -e "\e[33m$*\e[0m"
}

##
## 写入 sysctl 配置到独立文件 (避免污染 /etc/sysctl.conf)
##
_write_sysctl_conf() {
    local conf_file="/etc/sysctl.d/99-xray.conf"
    cat >"$conf_file" <<'EOF'
# =============================================
# Xray 内核参数优化
# 由 Xray 脚本自动生成和管理
# =============================================

# --- BBR 拥塞控制 ---
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# --- BBRv2 (内核 5.15+ 支持, 可选) ---
# net.ipv4.tcp_congestion_control = bbr2
# net.core.default_qdisc = fq

# --- TCP 连接优化 ---
# 增加 TCP SYN 队列和连接队列长度
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 8192

# 缩短 FIN 状态等待时间
net.ipv4.tcp_fin_timeout = 30

# TCP Keepalive 优化 (检测死连接)
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

# --- 本地端口范围 ---
net.ipv4.ip_local_port_range = 1024 65535

# --- TCP Fast Open ---
# 0=禁用 1=仅作为客户端 2=仅作为服务端 3=两者都启用
net.ipv4.tcp_fastopen = 3

# --- 内存和网络缓冲 ---
# TCP 读写缓冲区 (min default max)
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 通用 socket 缓冲区
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000

# --- 内存优化 ---
# 降低 swap 使用倾向
vm.swappiness = 10
EOF
}

##
## 启用 BBR (基础版, 内核 >= 4.9)
## 兼容旧版命令: xray bbr
##
_open_bbr() {
    local kernel_major kernel_minor
    kernel_major=$(uname -r | cut -d. -f1)
    kernel_minor=$(uname -r | cut -d. -f2)

    if [[ $kernel_major -lt 4 ]] || { [[ $kernel_major -eq 4 ]] && [[ $kernel_minor -lt 9 ]]; }; then
        _err "内核版本 $(uname -r) 过低，BBR 需要 >= 4.9"
        return 1
    fi

    # 写入完整 sysctl 配置 (包含 BBR + TCP 优化)
    _write_sysctl_conf

    # 应用配置
    if sysctl -p /etc/sysctl.d/99-xray.conf &>/dev/null; then
        echo
        _green "BBR + TCP 优化已启用!"
        echo
        echo "当前拥塞算法: $(sysctl -n net.ipv4.tcp_congestion_control)"
        echo "配置文件: /etc/sysctl.d/99-xray.conf"
        echo
    else
        _err "应用 sysctl 配置失败"
        return 1
    fi
}

##
## 尝试启用 BBR (带版本检查)
## 保留旧接口兼容
##
_try_enable_bbr() {
    _open_bbr
}

##
## 检查 BBR 状态
##
_check_bbr() {
    local congestion
    congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local qdisc
    qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)

    echo ""
    echo "=== BBR 状态 ==="
    echo "当前拥塞控制算法: $congestion"
    echo "当前队列规则: $qdisc"

    if [[ "$congestion" == *"bbr"* ]]; then
        _green "BBR 已启用 ✓"
    else
        _yellow "BBR 未启用 (当前: $congestion)"
        echo "运行 $is_core bbr 可启用"
    fi
    echo ""
}
