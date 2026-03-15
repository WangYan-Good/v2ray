# 更新已安装的脚本

如果已安装旧版本脚本，需要更新：

## 方式 1：使用 update.sh 命令（推荐）

```bash
v2ray update.sh
```

## 方式 2：重新安装

```bash
# 1. 卸载旧版本
cd /mnt/main/CodeSpace/OpenSource/v2ray
./install.sh --uninstall

# 2. 重新安装
./install.sh --tls nginx
```

## 方式 3：手动更新已安装的脚本

```bash
# 1. 复制最新脚本到安装目录
cp -rf /mnt/main/CodeSpace/OpenSource/v2ray/src/* /etc/v2ray/sh/src/

# 2. 复制主脚本
cp /mnt/main/CodeSpace/OpenSource/v2ray/v2ray.sh /etc/v2ray/sh/

# 3. 验证
v2ray version
```
