# T4: 下载文件 SHA256 校验测试用例

> 任务: 添加下载文件 SHA256 完整性校验
> 创建时间: 2026-04-07
> 状态: ✅ 已完成
> 负责人: -

---

## 背景

下载的二进制文件 (xray-core, jq, caddy) 没有完整性校验，容易被中间人篡改。

**checksum 数据源**:
| 组件 | 格式 | 来源 |
|------|------|------|
| **Xray-core** | `.dgst` 文件 (`SHA2-256= xxx`) | `${release_url}/${binary}.dgst` |
| **Caddy** | `checksums.txt` (标准 sha256sum 格式) | `${release_url}/caddy_${ver}_checksums.txt` |
| **jq** | 无 checksum 文件 | 跳过校验 |
| **dat** | 无 checksum 文件 | 跳过校验 |

---

## 测试用例总览

| 用例 ID | 测试类型 | 测试内容 | 优先级 |
|---------|----------|----------|--------|
| TC-01 | 功能测试 | Xray-core 下载 + SHA256 校验通过 | 🔴 P0 |
| TC-02 | 功能测试 | Caddy 下载 + SHA256 校验通过 | 🔴 P0 |
| TC-03 | 功能测试 | jq 下载 (无校验，正常通过) | 🔴 P0 |
| TC-04 | 异常测试 | Xray-core 校验失败 (篡改文件) | 🔴 P0 |
| TC-05 | 异常测试 | Xray-core 校验失败 (校验和错误) | 🔴 P0 |
| TC-06 | 异常测试 | .dgst 文件下载失败 (跳过校验) | 🟡 P1 |
| TC-07 | 异常测试 | checksums.txt 下载失败 (跳过校验) | 🟡 P1 |
| TC-08 | 功能测试 | `install.sh` 下载 + SHA256 校验 | 🔴 P0 |
| TC-09 | 功能测试 | `src/download.sh` 下载 + SHA256 校验 | 🔴 P0 |
| TC-10 | 集成测试 | 校验失败时安装终止且清理临时文件 | 🔴 P0 |
| E2E-01 | 端到端测试 | 全新安装 (模拟) 通过校验 | 🔴 P0 |

---

## TC-01: Xray-core 下载 + SHA256 校验通过

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 服务器可访问 GitHub Releases |
| **测试目标** | 验证 Xray-core 下载后自动校验 SHA256 通过 |

### 测试步骤

```bash
# 在服务器上模拟 download 函数调用
. /etc/xray/sh/src/init.sh
. /etc/xray/sh/src/download.sh

# 执行下载
download core $(xray version 2>/dev/null | head -1 | cut -d' ' -f1)
```

### 预期结果

```
✅ 下载 .dgst 文件成功
✅ 计算下载文件的 SHA256
✅ 校验和匹配
✅ 输出 "文件完整性验证通过: Xray"
✅ 文件被正确安装到 /etc/xray/bin/xray
```

---

## TC-02: Caddy 下载 + SHA256 校验通过

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 服务器可访问 GitHub Releases |
| **测试目标** | 验证 Caddy 下载后自动校验 SHA256 通过 |

### 测试步骤

```bash
. /etc/xray/sh/src/init.sh
. /etc/xray/sh/src/download.sh

download caddy
```

### 预期结果

```
✅ 下载 checksums.txt 文件成功
✅ 从中提取 caddy_${ver}_linux_amd64.tar.gz 的 SHA256
✅ 校验和匹配
✅ 输出 "文件完整性验证通过: Caddy"
```

---

## TC-03: jq 下载 (无校验，正常通过)

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 服务器可访问 GitHub Releases |
| **测试目标** | 验证无 checksum 文件时不阻塞安装 |

### 预期结果

```
✅ 下载成功
✅ 无校验步骤 (因为 jq 不提供 checksum)
✅ 不报错
```

---

## TC-04: Xray-core 校验失败 (篡改文件)

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 服务器可访问 GitHub Releases |
| **测试目标** | 验证篡改文件时校验失败并终止 |

### 测试步骤

```bash
# 手动下载 Xray-core 文件
wget -q -O /tmp/test-core.zip "https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-linux-64.zip"
# 篡改文件
echo "tampered" >> /tmp/test-core.zip

# 下载 checksum 文件
wget -q -O /tmp/test-core.zip.dgst "https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-linux-64.zip.dgst"

# 手动校验
actual_sha=$(sha256sum /tmp/test-core.zip | awk '{print $1}')
expected_sha=$(grep 'SHA2-256=' /tmp/test-core.zip.dgst | awk '{print $2}')
echo "Expected: $expected_sha"
echo "Actual:   $actual_sha"
echo "$actual_sha == $expected_sha"
```

### 预期结果

```
✅ SHA256 不匹配
✅ 脚本终止并输出 "错误: 文件校验和不匹配: Xray"
✅ 安装过程被终止
```

---

## TC-05: Xray-core 校验失败 (校验和错误)

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 服务器可访问 GitHub Releases |
| **测试目标** | 验证使用错误校验和时失败 |

### 测试步骤

```bash
# 正常下载
wget -q -O /tmp/test-core.zip "https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-linux-64.zip"

# 伪造 checksum 文件
echo "SHA2-256= 0000000000000000000000000000000000000000000000000000000000000000" > /tmp/test-core.zip.dgst

# 校验
actual_sha=$(sha256sum /tmp/test-core.zip | awk '{print $1}')
expected_sha=$(grep 'SHA2-256=' /tmp/test-core.zip.dgst | awk '{print $2}')
[[ "$actual_sha" != "$expected_sha" ]] && echo "✅ 校验失败: 不匹配" || echo "❌ 意外通过"
```

### 预期结果

```
✅ 校验失败
✅ 输出错误信息
```

---

## TC-06: .dgst 文件下载失败 (跳过校验)

| 字段 | 内容 |
|------|------|
| **优先级** | 🟡 P1 |
| **前置条件** | 模拟 .dgst 下载失败 |
| **测试目标** | 验证无法获取 checksum 时不阻塞安装 |

### 预期结果

```
✅ 下载完成
✅ .dgst 文件未获取到
✅ 跳过校验 (warn 提示)
✅ 安装继续
```

---

## TC-07: checksums.txt 下载失败 (跳过校验)

| 字段 | 内容 |
|------|------|
| **优先级** | 🟡 P1 |
| **前置条件** | 模拟 checksums.txt 下载失败 |
| **测试目标** | 验证无法获取 checksum 时不阻塞安装 |

### 预期结果

```
✅ 下载完成
✅ checksums.txt 未获取到
✅ 跳过校验 (warn 提示)
✅ 安装继续
```

---

## TC-08: install.sh 下载 + SHA256 校验

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 服务器可访问 GitHub Releases |
| **测试目标** | 验证 install.sh 中的 download() 函数集成校验 |

### 测试步骤

```bash
# 模拟 install.sh 的 download 函数
# 验证核心、脚本、jq 的下载校验
```

### 预期结果

```
✅ 每个下载完成后输出校验结果
✅ 校验失败时 install.sh 终止
```

---

## TC-09: src/download.sh 下载 + SHA256 校验

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 服务器可访问 GitHub Releases |
| **测试目标** | 验证 update core/update caddy 时的校验 |

### 预期结果

```
✅ xray update core 触发校验
✅ xray update caddy 触发校验
✅ 校验通过输出成功信息
```

---

## TC-10: 校验失败时安装终止且清理临时文件

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 模拟校验失败 |
| **测试目标** | 验证失败时临时文件被清理 |

### 预期结果

```
✅ 校验失败输出错误信息
✅ 调用 err() 终止安装
✅ 临时目录被清理
✅ 不安装被篡改的二进制文件
```

---

## E2E-01: 全新安装 (模拟) 通过校验

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 服务器环境正常 |
| **测试目标** | 模拟完整安装流程中校验通过 |

### 测试步骤

```bash
# 1. 删除现有二进制文件
rm -f /etc/xray/bin/xray

# 2. 运行 install.sh 或手动调用 download
. /etc/xray/sh/src/init.sh
. /etc/xray/sh/src/download.sh
download core v26.3.27

# 3. 验证文件安装
/etc/xray/bin/xray version
```

### 预期结果

```
✅ 下载 + 校验通过
✅ 文件可正常执行
✅ 版本号正确
```

---

## 测试结果汇总

| 用例 ID | 测试结果 | 执行时间 | 执行者 | 备注 |
|---------|----------|----------|--------|------|
| TC-01 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-02 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-03 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-04 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-05 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-06 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-07 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-08 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-09 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| TC-10 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |
| E2E-01 | ⬜ 通过 / ⬜ 失败 / ⬜ 跳过 | - | - | - |

---

*文档创建: 2026-04-07 | 状态: 待执行*
