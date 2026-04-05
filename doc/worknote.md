# 2026.04.03
## 🔴 严重问题

### 1. 安全：强制 ROOT 权限

- 位置：`install.sh` (第33行), `src/init.sh` (第35行)
- 问题：脚本强制要求 ROOT 权限，无非 ROOT 安装选项
- 风险：违反最小权限原则

### 2. 并行下载的竞态条件

- 位置：install.sh (第228-233行, 第337-341行)
- 问题：使用 & 和 wait 的多个后台下载可能导致竞态条件
- 示例：
```shell
download core &
download sh &
download jq &
get_ip
wait
```

- 风险：不可预测的行为，潜在的数据损坏

### 3. 禁用 SSL 验证

- 位置：install.sh (第104行), src/init.sh (第51行)
- 问题：wget --no-check-certificate 禁用了 SSL 证书验证
- 风险：容易受到中间人攻击

### 4. 下载文件无完整性验证

- 位置：install.sh, src/download.sh
- 问题：下载的二进制文件没有进行 SHA256/MD5 校验
- 风险：可能安装被篡改的文件而无法察觉


## 🟡 中等问题

### 5. 重复代码：TLS 选择逻辑

位置：install.sh (第389-485行)
问题：四个几乎相同的 while 循环用于 TLS 选择（复制粘贴代码）
影响：维护困难，容易引入 bug

### 6. 错误处理不一致

位置：多个文件
问题：有些函数使用 exit 1，有些使用 err()，有些静默返回
示例：
nginx.sh：证书失败返回 1
install.sh：调用 exit_and_del_tmpdir
core.sh：使用 err() 函数

### 7. 变量缺少引号

位置：整个代码库
问题：未加引号的变量可能导致单词分割和通配符错误
示例：
echo -e ${red}$@${none}  # 应该是: "${red}$*${none}"
rm -rf $tmpdir           # 应该是: "$tmpdir"

### 8. 硬编码路径

位置：多个文件
问题：/etc/v2ray, /usr/local/bin, /root/.bashrc 等路径硬编码
影响：不可移植，在容器环境中会出错

### 9. 安装缺乏幂等性

位置：install.sh
问题：多次运行安装脚本会导致 .bashrc 中出现重复的别名
第416行：echo "alias $is_core=$is_sh_bin" >>/root/.bashrc（每次都会追加）

### 10. 变量命名不规范

位置：src/core.sh
问题：混淆的变量名如 is_str, is_get, is_opt, is_opt3
第330行：[[ "$REPLY" == "${is_str}2${is_get}3${is_opt}3" && ... ]]
影响：难以维护，可能是隐藏的复活节彩蛋

### 11. 版本检测逻辑过于复杂

位置：src/init.sh (第96-110行)
问题：使用复杂的 grep/sed 逻辑检测 V2Ray v4 与 v5
风险：脆弱，版本号格式变化时会出错


### 12. 重复的状态检查

位置：install.sh (第325-333行 vs 第345-426行)
问题：步骤编号显示两次（旧逻辑 + 新的详细步骤）
影响：输出混乱，操作浪费

### 13. 错误时缺少清理

位置：nginx.sh (第224-228行)
问题：certbot 失败时，部分 Nginx 配置残留
风险：Nginx 状态损坏，需要手动清理

### 14. 用户输入无验证

位置：install.sh (第496-501行)
问题：域名输入未验证格式或 DNS 解析
风险：静默接受无效域名

### 15. 函数定义不一致

位置：多个文件
问题：_wget 在 install.sh 和 src/init.sh 中都有定义
影响：混淆，潜在冲突

## 🟢 轻微问题 / 代码异味

### 15. 魔术数字

位置：src/core.sh (第50行)
问题：shuf -i 0-${#ss_method_list[@]} -n1 没有解释

### 16. 不可达代码

位置：install.sh (第191行)
问题：online) 分支直接报错废弃信息
影响：死代码路径

### 17. 不一致的退出点

位置：install.sh
问题：多个退出点（第250行, 第285行, 第522行等）
影响：难以跟踪清理状态

### 18. 缺少日志记录

位置：install.sh
问题：安装过程未记录到日志文件
影响：难以调试失败

### 19. 被注释的代码

位置：src/core.sh (第14-23行, 第26-29行)
问题：被注释的协议选项没有解释
影响：对支持的功能产生混淆

### 20. Certbot 邮箱硬编码

位置：nginx.sh (第289, 314, 326行)
问题：--email admin@${domain} 硬编码
风险：LetsEncrypt 速率限制，隐私问题

### 21. 网络操作无超时

位置：多个文件
问题：_wget 调用缺少适当的超时设置
风险：慢速连接时脚本无限挂起

### 22. 依赖管理不一致

位置：install.sh (第67行)
问题：is_pkg="wget unzip" 但 jq 单独下载
影响：依赖管理不一致

### 23. 错误信息不友好

位置：多处
问题：通用的"哦豁…"错误信息对调试无帮助
示例：install.sh (第285行)

### 24. 无Dry-Run模式

问题：无法预览安装将执行的操作
影响：用户必须盲目信任脚本

---

# 2026.04.05

## 🔧 错误处理增强修复

### 问题背景

在远端服务器 `bak.yourdie.com` 部署时，VLESS-H2-TLS 配置安装失败，暴露出以下问题链路：

```
Certbot 参数错误 (--key-type ecdsa)
  ↓
证书实际未申请成功（但脚本显示"证书申请成功"）
  ↓
Nginx 启动失败（找不到证书文件）
  ↓
配置冲突提示（V2Ray 路径与 Nginx location 不匹配）
  ↓
用户被迫选择重新生成，但再次失败
```

### 修复内容

#### 1. Certbot 版本检查修复 (`src/nginx.sh`)

**问题**：`_is_certbot_support_ecdsa()` 函数仅识别 `>= 2.0` 版本，但 `--key-type ecdsa` 参数在 `1.12.0` 就引入了

**修复**：
```bash
_is_certbot_support_ecdsa() {
    local ver
    ver=$(certbot --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+')
    local major="${ver%%.*}"
    local minor="${ver##*.}"
    # 版本 >= 1.12 或 >= 2.0 都支持
    if [[ "$major" -ge 2 ]]; then
        return 0
    elif [[ "$major" -eq 1 && "$minor" -ge 12 ]]; then
        return 0
    fi
    return 1
}
```

#### 2. Certbot 退出码正确捕获 (`src/nginx.sh`)

**问题**：使用 `| while` 管道后，`certbot` 的退出码丢失

**修复**：使用 `PIPESTATUS` 捕获真实退出码
```bash
certbot certonly --standalone \
    -d ${domain} \
    $(_is_certbot_support_ecdsa && echo "--key-type ecdsa") \
    2>&1 | while IFS= read -r line; do
        [[ $line ]] && msg info "  $line"
    done
certbot_exit_code=${PIPESTATUS[0]}
if [[ $certbot_exit_code -eq 0 ]]; then
    msg ok "证书申请成功"
else
    msg err "证书申请失败"
    return 1
fi
```

#### 3. 证书文件验证增强 (`src/nginx.sh`)

**问题**：未验证证书文件是否真实存在就创建软链接

**修复**：`_create_cert_link()` 函数增加三重验证
- 验证证书文件存在（`fullchain.pem` 和 `privkey.pem`）
- 验证证书有效性（使用 `openssl x509 -noout` 解析）
- 创建软链接后二次验证文件可访问性

#### 4. Nginx 启动验证和回滚 (`src/nginx.sh`)

**问题**：Nginx 启动失败后未回滚配置，用户看到"安装成功"但服务无法运行

**修复**：
- 启动前执行 `nginx -t` 测试配置
- 启动失败时提供明确的修复指引
- 证书失败时自动清理生成的 Nginx 配置文件

```bash
# 测试并启动 Nginx
msg warn "测试 Nginx 配置..."
if ! nginx -t 2>&1; then
    msg err "Nginx 配置测试失败"
    msg warn "已生成证书但 Nginx 配置有问题"
    msg warn "请检查：nginx -t"
    msg warn "查看详细错误：journalctl -u nginx -n 50"
    return 1
fi
```

#### 5. 安装失败时自动回滚 (`install.sh`)

**问题**：`exit_and_del_tmpdir()` 仅清理临时目录，未清理已安装到系统的文件

**修复**：失败时自动清理以下文件
- `/etc/v2ray/sh/` - 脚本目录
- `/etc/v2ray/bin/` - 核心目录
- `/usr/local/bin/v2ray` - 命令链接
- `/var/log/v2ray/` - 日志目录
- `/root/.bashrc` 中的别名
- systemd 服务文件
- `/etc/nginx/v2ray/*.conf` - 失败的 Nginx 配置
- `/etc/nginx/ssl/域名/` - 失败的证书链接

```bash
exit_and_del_tmpdir() {
    rm -rf $tmpdir

    # 失败时回滚已安装的文件
    if [[ ! $1 ]]; then
        if [[ -d $is_sh_dir || -d $is_core_dir/bin || -f $is_sh_bin ]]; then
            msg warn "检测到部分安装文件，正在清理..."
            [[ -d $is_sh_dir ]] && rm -rf $is_sh_dir
            [[ -d $is_core_dir ]] && rm -rf $is_core_dir
            [[ -f $is_sh_bin ]] && rm -f $is_sh_bin
            [[ -d $is_log_dir ]] && rm -rf $is_log_dir
            # ... 清理其他文件
        fi
        msg err "安装过程出现错误..."
        exit 1
    fi
    exit
}
```

#### 6. 错误提示优化

**所有失败场景均提供**：
- 详细的错误日志路径
- 具体的修复步骤
- 可执行的命令示例

```bash
msg err "证书申请失败"
msg warn "请检查:"
msg "  1. 域名是否正确解析到服务器 IP"
msg "  2. 防火墙是否开放 80 端口"
msg "  3. 查看详细日志：tail -20 /var/log/letsencrypt/letsencrypt.log"
```

### 修复优先级

| 优先级 | 修复项 | 影响 |
|--------|--------|------|
| **P0** | Certbot 退出码修复 | 高 - 直接导致证书失败但误判成功 |
| **P0** | 证书文件验证 | 高 - 避免创建无效软链接 |
| **P1** | Nginx 启动回滚 | 中 - 失败后保持系统可用 |
| **P1** | 配置清理 | 中 - 避免残留无效配置 |
| **P2** | 错误提示优化 | 低 - 改善用户体验 |

### 遗留问题（后续修复）

| 问题编号 | 问题 | 建议方案 |
|---------|------|---------|
| 13 | certbot 失败时部分 Nginx 配置残留 | ✅ 已修复：证书失败时自动清理配置 |
| 23 | 错误信息不友好 | ✅ 已修复：提供详细的错误日志路径和修复步骤 |
| 6 | 错误处理不一致 | ✅ 已修复：统一使用 `return 1` 和详细的错误提示 |
| 17 | 不一致的退出点 | 部分修复：失败时统一调用回滚逻辑 |

### 测试建议

1. **Certbot 版本测试**
   - Certbot 1.12.x 应正确使用 `--key-type ecdsa`
   - Certbot 1.11.x 应不使用 `--key-type ecdsa`
   - Certbot 2.x 应正确使用 `--key-type ecdsa`

2. **失败回滚测试**
   - 模拟证书申请失败，验证是否清理了残留配置
   - 模拟 Nginx 启动失败，验证是否提供了修复指引
   - 模拟安装中断，验证是否清理了已安装的文件

3. **证书验证测试**
   - 证书文件不存在时应报错
   - 证书文件损坏时应报错
   - 软链接创建后应二次验证