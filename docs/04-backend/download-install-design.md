# 下载与安装设计

## 目标

本文档定义 Phase 4 的下载、校验、安装/更新计划模型。它不描述真实系统写入执行器，而是固定执行器之前必须满足的纯数据合同。

## 包结构

```text
internal/download/
  arch.go          架构映射
  plan.go          asset URL 和安装目标
  checksum.go      SHA256 和 release metadata parser
  install_plan.go  安装/更新步骤
```

## 架构映射

| machine | Go | Xray Core | Caddy | jq |
| --- | --- | --- | --- | --- |
| `x86_64` / `amd64` | `amd64` | `64` | `amd64` | `amd64` |
| `aarch64` / `arm64` / `armv8*` | `arm64` | `arm64-v8a` | `arm64` | `arm64` |

不支持的架构必须返回错误，不生成下载 URL。

## Asset 命名

| kind | asset | checksum |
| --- | --- | --- |
| `core` | `Xray-linux-{xrayArch}.zip` | `{url}.dgst` |
| `script` | `code.zip` | GitHub asset digest 或 release checksums |
| `caddy` | `caddy_{versionWithoutV}_linux_{caddyArch}.tar.gz` | `caddy_{versionWithoutV}_checksums.txt` |
| `dat` | `geoip.dat`、`geosite.dat` | 无固定 checksum，后续可接入 upstream checksum |
| `jq` | `jq-linux-{jqArch}` | GitHub asset digest |
| `go` | `xray-linux-{goArch}.tar.gz` | `checksums.txt` |

## URL 规则

GitHub release tag URL：

```text
https://github.com/{repo}/releases/download/{version}/{asset}
```

latest URL：

```text
https://github.com/{repo}/releases/latest/download/{asset}
```

Caddy 需要版本号来生成 asset name；自动 latest 解析应先通过 GitHub API 获取 tag，再生成 plan。

## SHA256

Go 需要支持：

- `SHA256Hex([]byte)`。
- `VerifySHA256([]byte, expected)`。
- `ParseXrayDigest(text)`：读取 `SHA2-256=`。
- `ParseChecksum(text, asset)`：从 checksums 文本中匹配 asset。
- `SelectAssetDigest(releaseJSON, asset)`：读取 GitHub Release API asset digest，去掉 `sha256:` 前缀。

checksum mismatch 返回 checksum 错误；checksum 缺失不得静默伪装为通过。

## Proxy 环境

当用户提供 proxy：

```text
http_proxy={proxy}
https_proxy={proxy}
HTTP_PROXY={proxy}
HTTPS_PROXY={proxy}
```

计划输出必须包含这些键，后续执行器据此设置环境。

## 安装/更新步骤

计划步骤使用纯文本描述，不执行：

新安装：

- create `/etc/xray/sh`
- create `/etc/xray/bin`
- create `/etc/xray/conf`
- create `/var/log/xray`
- extract `code.zip` to `/etc/xray/sh`
- extract core zip to `/etc/xray/bin`
- install or keep `/usr/local/bin/xray`
- install systemd service

保留配置重装：

- keep `/etc/xray/conf`
- replace `/etc/xray/sh`
- replace `/etc/xray/bin`
- reload systemd service

更新：

- core update: replace `/etc/xray/bin/xray` and data files.
- script update: replace `/etc/xray/sh`.
- go update: replace `/usr/local/bin/xray` only after Phase 5 switch.

## Release workflow

Release 必须继续上传：

- `code.zip`
- `install.sh`

Phase 4 新增上传：

- `xray-linux-amd64.tar.gz`
- `xray-linux-arm64.tar.gz`
- `checksums.txt`

Go 二进制构建命令：

```bash
GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o dist/xray-linux-amd64/xray ./cmd/xray
GOOS=linux GOARCH=arm64 go build -trimpath -ldflags "-s -w" -o dist/xray-linux-arm64/xray ./cmd/xray
```

## 后续接入

- Phase 5 才允许 `/usr/local/bin/xray` 默认指向 Go binary。
- Phase 5 需要 legacy 委托，保证未迁移命令仍可用。
- Phase 6 才删除 Bash 下载和安装旧逻辑。
