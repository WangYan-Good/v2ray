# V2Ray Phase 9 - Info 功能诊断报告

## 执行时间
2026-03-25 18:28 UTC

## 问题描述

用户测试发现 "查看配置"（info）功能输出为空，但测试脚本报告通过。

## 诊断过程

### 1. 代码检查

检查了 `info()` 函数和 `get info` 函数的实现：

**info() 函数位置**: `/home/node/.openclaw/v2ray/src/core.sh` (行 1927+)

**get info 函数位置**: `/home/node/.openclaw/v2ray/src/core.sh` (行 1380+)

### 2. 模拟测试

创建了测试脚本模拟 info 功能：

```bash
# 创建测试配置
/tmp/v2ray-test/test-config.json

# 运行诊断
bash /tmp/v2ray-test/diagnose.sh
```

### 3. 测试结果

#### 3.1 jq 调用失败

所有 jq 命令均失败：
```bash
jq: command not found
```

#### 3.2 变量加载失败

所有关键变量为空：
```bash
IS_PROTOCOL:
PORT:
UUID:
TROJAN_PASSWORD:
NET:
HOST:
URL_PATH:
GRPC_SERVICE_NAME:
```

#### 3.3 info 输出

输出仅显示：
```
-------------- test-config.json -------------
------------- END -------------
```

没有显示任何配置信息。

## 根本原因分析

### 主要问题：jq 依赖问题

1. **Python jq wrapper 不完整**
   - 位置: `/tmp/jq`
   - 类型: Python 脚本
   - 问题: 不支持完整的 jq 语法，特别是逗号分隔的字段提取

2. **jq 调用失败**
   - 所有 jq 解析命令返回错误码 127
   - 错误信息: `jq: command not found`
   - 即使 `/tmp/jq` 存在且可执行，shell 也找不到 jq 命令

3. **依赖链断裂**
   ```
   get info → jq 解析 JSON → 变量为空 → info() 显示空内容
   ```

### 次要问题：信息显示逻辑

1. **IS_INFO_SHOW 数组为空**
   - `info()` 函数中 `IS_INFO_SHOW` 数组依赖 `NET` 变量
   - 当 `NET` 为空时，数组为空
   - 结果：不显示任何配置信息

2. **错误处理不足**
   - jq 失败后仅调用 `err()`，但没有停止执行
   - `err()` 函数也可能调用失败（在测试中看到）

## 技术细节

### jq 查询失败的具体位置

**BASE 查询** (行 1388):
```bash
jq -r '(.inbounds[0].protocol//""),(.inbounds[0].port//""),(...)'
```

**MORE 查询** (行 1390):
```bash
jq -r '(.inbounds[0].streamSettings.network//""),(.inbounds[0].streamSettings.security//""),(...)'
```

**HOST 查询** (行 1395):
```bash
jq -r '(.inbounds[0].streamSettings.grpc_host//""),(.inbounds[0].streamSettings.wsSettings.headers.Host//""),(...)'
```

### 变量依赖关系

```
IS_PROTOCOL (from JSON)
    ↓
PORT (from JSON)
    ↓
UUID/TROJAN_PASSWORD (from JSON)
    ↓
NET (from JSON)
    ↓
IS_INFO_SHOW 数组 (依赖 NET)
    ↓
IS_INFO_STR 数组 (依赖上述所有变量)
    ↓
msg 输出 (显示 IS_INFO_STR)
```

## 结论

**根本原因**: `/tmp/jq` Python wrapper 不支持完整的 jq 语法，导致所有 JSON 解析失败，进而导致 info 功能无法显示任何配置信息。

**影响范围**:
- 所有依赖 jq 解析 JSON 的功能
- 特别是 `get info` 和 `info()` 函数
- 测试脚本仅检查退出码，未验证输出内容，导致假阴性结果

## 修复方向

1. **安装真正的 jq 二进制文件** (推荐)
   - 下载官方 jq 二进制
   - 替换 Python wrapper

2. **增强 Python jq wrapper** (备选)
   - 添加逗号分隔字段提取支持
   - 添加更多 jq 语法支持

3. **改进错误处理**
   - jq 失败时显示明确错误信息
   - 提供降级方案或备用解析方法

4. **改进测试脚本**
   - 验证输出内容而非仅检查退出码
   - 添加 info 功能的输出验证

## 下一步

进入 Phase 2: 修复问题