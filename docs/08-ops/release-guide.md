# 自动发布流程

## 概述

当推送匹配 `v*.*.*` 或 `v*-release` 格式的 tag 时，GitHub Actions 会自动：

1. 构建 Linux amd64/arm64 Go CLI tarball。
2. 生成 `checksums.txt`。
3. 创建 GitHub Release。
4. 上传 `install.sh`、`xray-linux-amd64.tar.gz`、`xray-linux-arm64.tar.gz`、`checksums.txt`。
5. 自动生成更新日志和远程安装示例。

`code.zip`、`xray.sh` 和 `src/` 不再是发布资产。

## 使用方法

```bash
git tag -a v2.0.0-release -m "Release v2.0.0"
git push origin v2.0.0-release
```

发布完成后，远程一键安装仍使用：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/WangYan-Good/xray/v2.0.0-release/install.sh)
```

## Release Assets

- `install.sh`：远程 bootstrap，下载并校验 Go CLI。
- `xray-linux-amd64.tar.gz`：Linux amd64 Go CLI。
- `xray-linux-arm64.tar.gz`：Linux arm64 Go CLI。
- `checksums.txt`：Go CLI tarball SHA256。

## 故障排查

- Release 未触发：检查 tag 是否匹配 `v*.*.*` 或 `v*-release`。
- tarball 未上传：查看 `Build Go CLI assets` 步骤。
- 一键安装失败：确认 `install.sh`、目标架构 tarball 和 `checksums.txt` 都存在于同一 Release。
