# 系统设计

## 当前架构

项目当前是 Go CLI 架构：

```text
install.sh
  |
  | downloads xray-linux-{arch}.tar.gz and verifies checksums.txt
  v
/usr/local/bin/xray
  |
  +-- install/update/uninstall
  +-- add/change/del/info/url/client
  +-- Nginx/Caddy/Certbot integration
  +-- Mihomo subscription generation
  +-- systemd and Xray-core passthrough
```

`install.sh` 是远程一键安装 bootstrap，不承载协议、订阅、证书或服务管理业务逻辑。

## 生产文件布局

| 路径 | 用途 |
| --- | --- |
| `/usr/local/bin/xray` | Go CLI 入口 |
| `/etc/xray/bin/xray` | Xray-core 二进制 |
| `/etc/xray/config.json` | 主配置 |
| `/etc/xray/conf/*.json` | 管理节点配置 |
| `/etc/xray/sub/mihomo.yaml` | Mihomo 订阅文件 |
| `/etc/nginx/xray/*.conf` | Nginx TLS 前端配置 |
| `/etc/caddy/WangYan-Good/*.conf` | Caddy TLS 前端配置 |
| `/etc/systemd/system/xray.service` | Xray systemd 服务 |

旧 Bash runtime (`xray.sh`、`src/`、`/etc/xray/sh`) 已删除，不再是生产路径。

## Go 包边界

| 包 | 职责 |
| --- | --- |
| `cmd/xray` | CLI 入口 |
| `internal/app` | 命令路由、写入命令和系统操作编排 |
| `internal/config` | 节点配置读取、匹配和扁平模型 |
| `internal/protocol` | 协议 profile、Xray JSON、URL、client JSON、Mihomo YAML |
| `internal/frontend/nginx` | Nginx 模板、include 修复、Certbot renewal 模型 |
| `internal/frontend/caddy` | Caddy 模板和导入模型 |
| `internal/download` | release asset、架构映射和 checksum 计划 |
| `internal/ui` | 稳定文本输出 |

## 命令模型

所有公开命令由 Go 识别和处理。未识别命令返回 usage error，不委托 Bash。

高副作用命令通过 `--root` 支持测试根目录，自动化测试不得写真实 `/etc`、调用真实 Certbot、systemd 或公网业务资源。

## 发布模型

Release assets:

- `install.sh`
- `xray-linux-amd64.tar.gz`
- `xray-linux-arm64.tar.gz`
- `checksums.txt`

`code.zip` 不再发布。
