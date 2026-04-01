#!/bin/bash
# error.sh - 统一错误处理和输入验证模块

##
## 错误码定义
##
readonly ERR_SUCCESS=0
readonly ERR_GENERAL=1
readonly ERR_INVALID_ARGS=2
readonly ERR_PERMISSION_DENIED=3
readonly ERR_FILE_NOT_FOUND=4
readonly ERR_NETWORK=5
readonly ERR_DEPENDENCY=6
readonly ERR_CONFIG=7
readonly ERR_SERVICE=8

##
## 统一错误处理函数
##
error_exit() {
    local message="$1"
    local code="${2:-$ERR_GENERAL}"
    log_error "$message"
    exit "$code"
}

check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        error_exit "Required command '$cmd' not found" "$ERR_DEPENDENCY"
    fi
}

##
## 输入验证函数
##
validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error_exit "Invalid port number: $port" "$ERR_INVALID_ARGS"
    fi
}

validate_uuid() {
    local uuid="$1"
    if ! [[ "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        error_exit "Invalid UUID format: $uuid" "$ERR_INVALID_ARGS"
    fi
}

validate_domain() {
    local domain="$1"
    if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        error_exit "Invalid domain format: $domain" "$ERR_INVALID_ARGS"
    fi
}

validate_email() {
    local email="$1"
    if ! [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        error_exit "Invalid email format: $email" "$ERR_INVALID_ARGS"
    fi
}

validate_path() {
    local path="$1"
    if [[ -z "$path" ]]; then
        error_exit "Path cannot be empty" "$ERR_INVALID_ARGS"
    fi
    # 检查路径是否包含危险字符
    if [[ "$path" =~ [\;\|\&\$\`\(\)] ]]; then
        error_exit "Invalid path characters: $path" "$ERR_INVALID_ARGS"
    fi
}

validate_number() {
    local num="$1"
    local min="${2:-}"
    local max="${3:-}"
    
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        error_exit "Invalid number: $num" "$ERR_INVALID_ARGS"
    fi
    
    if [[ -n "$min" ]] && [ "$num" -lt "$min" ]; then
        error_exit "Number $num is less than minimum $min" "$ERR_INVALID_ARGS"
    fi
    
    if [[ -n "$max" ]] && [ "$num" -gt "$max" ]; then
        error_exit "Number $num is greater than maximum $max" "$ERR_INVALID_ARGS"
    fi
}

validate_non_empty() {
    local value="$1"
    local name="${2:-Value}"
    
    if [[ -z "$value" ]]; then
        error_exit "$name cannot be empty" "$ERR_INVALID_ARGS"
    fi
}

validate_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        error_exit "File not found: $file" "$ERR_FILE_NOT_FOUND"
    fi
}

validate_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        error_exit "Directory not found: $dir" "$ERR_FILE_NOT_FOUND"
    fi
}

validate_ip() {
    local ip="$1"
    if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # 尝试 IPv6
        if ! [[ "$ip" =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]]; then
            error_exit "Invalid IP address: $ip" "$ERR_INVALID_ARGS"
        fi
    fi
}

##
## 权限检查
##
check_root() {
    if [[ $EUID != 0 ]]; then
        error_exit "This script must be run as root" "$ERR_PERMISSION_DENIED"
    fi
}

##
## 依赖检查
##
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error_exit "Missing dependencies: ${missing[*]}" "$ERR_DEPENDENCY"
    fi
}
