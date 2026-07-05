# 自动发布流程

## 概述

当推送匹配 `v*.*.*` 或 `v*-release` 格式的 tag 时，GitHub Actions 会自动：
1. 打包 `code.zip`（包含 `xray.sh` 和 `src/` 目录）
2. 创建 GitHub Release
3. 上传 `code.zip`、`install.sh`、Go CLI tarball 和 `checksums.txt` 作为 release assets
4. 自动生成更新日志

## 使用方法

### 1. 发布新版本

```bash
# 确保代码已提交
git add -A
git commit -m "release: 准备发布 v1.0.3"

# 创建并推送 tag（触发自动发布）
git tag -a v1.0.3-release -m "Release v1.0.3"
git push origin v1.0.3-release

# 或者同时推送分支和 tag
git push origin v1.0.3-release --tags
```

### 2. 查看发布进度

访问：https://github.com/WangYan-Good/xray/actions

### 3. 发布完成后

Release 会自动创建，包含：
- ✅ `code.zip` - 脚本安装包
- ✅ `install.sh` - 安装脚本
- ✅ `xray-linux-amd64.tar.gz` - Go CLI amd64 预览入口
- ✅ `xray-linux-arm64.tar.gz` - Go CLI arm64 预览入口
- ✅ `checksums.txt` - Go CLI tarball SHA256
- ✅ 自动生成的更新日志
- ✅ 安装命令示例

## 触发条件

以下 tag 格式会触发自动发布：

| Tag 格式 | 示例 | 说明 |
|---------|------|------|
| `v*.*.*` | `v1.0.3` | 标准版本号 |
| `v*-release` | `v1.0.3-release` | 带 release 后缀 |

## 自定义

如需修改打包内容，编辑 `.github/workflows/release.yml` 中的 `Create code.zip` 步骤：

```yaml
- name: Create code.zip
  run: |
    # 修改这里来调整打包内容
    zip -r code.zip xray.sh src/
```

## 故障排查

### Release 未触发

1. 检查 tag 格式是否匹配触发条件
2. 查看 Actions 页面是否有工作流运行
3. 检查 `.github/workflows/release.yml` 语法是否正确

### code.zip 未上传

1. 查看 Actions 日志确认打包步骤是否成功
2. 检查 `verify release assets` 步骤的输出
3. 手动上传：
   ```bash
   gh release upload v1.0.3-release code.zip
   ```

### 权限问题

确保仓库设置中：
- Settings > Actions > General > Workflow permissions = "Read and write permissions"
- 或为 GITHUB_TOKEN 添加 `contents: write` 权限
