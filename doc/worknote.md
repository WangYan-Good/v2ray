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

### 1. 重复代码：TLS 选择逻辑

位置：install.sh (第389-485行)
问题：四个几乎相同的 while 循环用于 TLS 选择（复制粘贴代码）
影响：维护困难，容易引入 bug
错误处理不一致

位置：多个文件
问题：有些函数使用 exit 1，有些使用 err()，有些静默返回
示例：
nginx.sh：证书失败返回 1
install.sh：调用 exit_and_del_tmpdir
core.sh：使用 err() 函数
变量缺少引号

位置：整个代码库
问题：未加引号的变量可能导致单词分割和通配符错误
示例：
echo -e ${red}$@${none}  # 应该是: "${red}$*${none}"
rm -rf $tmpdir           # 应该是: "$tmpdir"
硬编码路径

位置：多个文件
问题：/etc/v2ray, /usr/local/bin, /root/.bashrc 等路径硬编码
影响：不可移植，在容器环境中会出错
安装缺乏幂等性

位置：install.sh
问题：多次运行安装脚本会导致 .bashrc 中出现重复的别名
第416行：echo "alias $is_core=$is_sh_bin" >>/root/.bashrc（每次都会追加）
变量命名不规范

位置：src/core.sh
问题：混淆的变量名如 is_str, is_get, is_opt, is_opt3
第330行：[[ "$REPLY" == "${is_str}2${is_get}3${is_opt}3" && ... ]]
影响：难以维护，可能是隐藏的复活节彩蛋
版本检测逻辑过于复杂

位置：src/init.sh (第96-110行)
问题：使用复杂的 grep/sed 逻辑检测 V2Ray v4 与 v5
风险：脆弱，版本号格式变化时会出错
重复的状态检查

位置：install.sh (第325-333行 vs 第345-426行)
问题：步骤编号显示两次（旧逻辑 + 新的详细步骤）
影响：输出混乱，操作浪费
错误时缺少清理

位置：nginx.sh (第224-228行)
问题：certbot 失败时，部分 Nginx 配置残留
风险：Nginx 状态损坏，需要手动清理
用户输入无验证

位置：install.sh (第496-501行)
问题：域名输入未验证格式或 DNS 解析
风险：静默接受无效域名
函数定义不一致

位置：多个文件
问题：_wget 在 install.sh 和 src/init.sh 中都有定义
影响：混淆，潜在冲突
🟢 轻微问题 / 代码异味
魔术数字

位置：src/core.sh (第50行)
问题：shuf -i 0-${#ss_method_list[@]} -n1 没有解释
不可达代码

位置：install.sh (第191行)
问题：online) 分支直接报错废弃信息
影响：死代码路径
不一致的退出点

位置：install.sh
问题：多个退出点（第250行, 第285行, 第522行等）
影响：难以跟踪清理状态
缺少日志记录

位置：install.sh
问题：安装过程未记录到日志文件
影响：难以调试失败
被注释的代码

位置：src/core.sh (第14-23行, 第26-29行)
问题：被注释的协议选项没有解释
影响：对支持的功能产生混淆
Certbot 邮箱硬编码

位置：nginx.sh (第289, 314, 326行)
问题：--email admin@${domain} 硬编码
风险：LetsEncrypt 速率限制，隐私问题
网络操作无超时

位置：多个文件
问题：_wget 调用缺少适当的超时设置
风险：慢速连接时脚本无限挂起
依赖管理不一致

位置：install.sh (第67行)
问题：is_pkg="wget unzip" 但 jq 单独下载
影响：依赖管理不一致
错误信息不友好

位置：多处
问题：通用的"哦豁…"错误信息对调试无帮助
示例：install.sh (第285行)
无Dry-Run模式

问题：无法预览安装将执行的操作
影响：用户必须盲目信任脚本