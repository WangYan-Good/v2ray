# Phase 1 快速参考指南

## 新增功能速查

### 1. 错误码定义

```bash
# 在脚本中加载
source src/error.sh

# 可用错误码
ERR_SUCCESS=0           # 成功
ERR_GENERAL=1           # 一般错误
ERR_INVALID_ARGS=2      # 无效参数
ERR_PERMISSION_DENIED=3 # 权限拒绝
ERR_FILE_NOT_FOUND=4    # 文件未找到
ERR_NETWORK=5           # 网络错误
ERR_DEPENDENCY=6        # 依赖缺失
ERR_CONFIG=7            # 配置错误
ERR_SERVICE=8           # 服务错误
```

### 2. 错误处理函数

```bash
# 错误退出
error_exit "错误信息" "$ERR_INVALID_ARGS"

# 检查命令是否存在
check_command "wget"  # 不存在则自动退出

# 检查依赖包
check_dependencies "wget" "unzip" "jq"

# 检查 root 权限
check_root
```

### 3. 输入验证函数

```bash
# 端口验证 (1-65535)
validate_port 8080

# UUID 验证
validate_uuid "550e8400-e29b-41d4-a716-446655440000"

# 域名验证
validate_domain "example.com"

# 邮箱验证
validate_email "user@example.com"

# 路径验证 (安全检查)
validate_path "/etc/v2ray/config.json"

# 数字范围验证
validate_number "$PORT" 1 65535

# 非空验证
validate_non_empty "$VAR" "变量名"

# 文件/目录存在性验证
validate_file_exists "/path/to/file"
validate_dir_exists "/path/to/dir"

# IP 地址验证 (IPv4/IPv6)
validate_ip "192.168.1.1"
```

### 4. 日志系统

```bash
# 加载日志模块
source src/log.sh

# 标准日志
log_info "这是一条信息"
log_warn "这是一条警告"
log_error "这是一个错误"
log_debug "这是调试信息"  # 仅当 DEBUG=true 时显示

# 带颜色的日志 (终端显示)
log_info_color "绿色信息"
log_warn_color "黄色警告"
log_error_color "红色错误"
log_debug_color "灰色调试"

# 设置日志级别
export LOG_LEVEL=1  # 0=debug, 1=info, 2=warn, 3=error, 4=none
```

## 使用示例

### 示例 1: 安装脚本中的使用

```bash
#!/bin/bash
source src/error.sh
source src/log.sh

main() {
    # 检查权限
    check_root
    
    # 检查依赖
    check_dependencies "wget" "unzip" "jq"
    
    # 获取用户输入并验证
    read -p "请输入端口号：" PORT
    validate_port "$PORT"
    
    read -p "请输入域名：" DOMAIN
    validate_domain "$DOMAIN"
    
    # 执行操作
    log_info "开始安装..."
    
    if ! wget "https://example.com/file.zip" -O "/tmp/file.zip"; then
        error_exit "下载失败" "$ERR_NETWORK"
    fi
    
    log_info "安装完成"
}

main "$@"
```

### 示例 2: 配置验证

```bash
#!/bin/bash
source src/error.sh
source src/log.sh

validate_config() {
    local config_file="$1"
    
    # 检查配置文件是否存在
    validate_file_exists "$config_file"
    
    # 读取配置并验证
    local port=$(jq -r '.port' "$config_file")
    validate_port "$port"
    
    local uuid=$(jq -r '.uuid' "$config_file")
    validate_uuid "$uuid"
    
    local domain=$(jq -r '.domain' "$config_file")
    validate_domain "$domain"
    
    log_info "配置验证通过"
}

validate_config "/etc/v2ray/config.json"
```

### 示例 3: 交互式菜单

```bash
#!/bin/bash
source src/error.sh
source src/log.sh

show_menu() {
    echo "1) 安装 V2Ray"
    echo "2) 更新配置"
    echo "3) 查看状态"
    echo "4) 退出"
}

main() {
    while true; do
        show_menu
        read -p "请选择 [1-4]: " choice
        
        # 验证输入
        validate_number "$choice" 1 4
        
        case $choice in
            1) install_v2ray ;;
            2) update_config ;;
            3) show_status ;;
            4) 
                log_info "退出程序"
                exit $ERR_SUCCESS
                ;;
        esac
    done
}

main
```

## 最佳实践

### ✅ 推荐做法

1. **始终验证用户输入**
   ```bash
   # 好
   validate_port "$PORT"
   
   # 不好
   if [ "$PORT" -gt 0 ]; then
   ```

2. **使用统一的错误处理**
   ```bash
   # 好
   error_exit "操作失败" "$ERR_SERVICE"
   
   # 不好
   echo "错误"; exit 1
   ```

3. **使用有意义的错误码**
   ```bash
   # 好
   exit $ERR_INVALID_ARGS
   
   # 不好
   exit 99
   ```

4. **添加详细的日志**
   ```bash
   # 好
   log_info "开始下载核心文件..."
   log_info "下载完成"
   
   # 不好
   echo "下载"
   ```

### ❌ 避免的做法

1. **不要忽略错误**
   ```bash
   # 不好
   some_command || true
   
   # 好
   if ! some_command; then
       error_exit "命令执行失败" "$ERR_GENERAL"
   fi
   ```

2. **不要使用未验证的输入**
   ```bash
   # 不好
   rm -rf /path/$USER_INPUT
   
   # 好
   validate_path "$USER_INPUT"
   rm -rf "/path/$USER_INPUT"
   ```

3. **不要混合使用日志级别**
   ```bash
   # 不好
   echo "错误：$msg"
   
   # 好
   log_error "$msg"
   ```

## 故障排除

### 常见问题

**Q: validate_port 总是退出脚本**
```bash
# 原因：error_exit 会调用 exit
# 解决：在测试或需要继续执行时使用 IS_DONT_AUTO_EXIT

IS_DONT_AUTO_EXIT=1
validate_port "$PORT" || echo "端口无效"
```

**Q: 日志不显示颜色**
```bash
# 原因：可能重定向到了文件
# 解决：使用标准日志函数，颜色函数仅用于终端

log_info "写入日志文件"      # ✅
log_info_color "终端显示"    # ✅
```

**Q: 如何自定义错误消息**
```bash
# 可以直接调用 log_error 然后 exit
log_error "自定义错误：详细信息..."
exit $ERR_CONFIG
```

## 测试命令

```bash
# 快速测试所有功能
cd /etc/v2ray/sh
bash -c '
  source src/error.sh
  source src/log.sh
  
  echo "测试错误码..."
  echo "ERR_SUCCESS=$ERR_SUCCESS"
  
  echo "测试验证函数..."
  IS_DONT_AUTO_EXIT=1
  validate_port 8080 && echo "端口验证：OK"
  validate_uuid "550e8400-e29b-41d4-a716-446655440000" && echo "UUID 验证：OK"
  validate_domain "example.com" && echo "域名验证：OK"
  
  echo "测试日志系统..."
  log_info "信息日志"
  log_warn "警告日志"
  log_error "错误日志"
  
  echo "所有测试通过!"
'
```

## 文件位置

```
/etc/v2ray/sh/
├── install.sh              # 主安装脚本 (已修复)
├── src/
│   ├── error.sh           # 错误处理模块 (新增)
│   ├── log.sh             # 日志系统 (更新)
│   ├── init.sh            # 初始化脚本 (更新)
│   └── core.sh            # 核心功能 (待更新)
├── test_improvements.sh   # 测试脚本
└── PHASE1_REPORT.md       # 详细报告
```

## 相关文档

- 详细报告：`PHASE1_REPORT.md`
- 原始任务：任务描述文档
- ShellCheck 规则：https://github.com/koalaman/shellcheck/wiki

---

**最后更新**: 2026-03-22  
**版本**: Phase 1  
**状态**: ✅ 已完成
