# V2Ray Phase 9 - JSON_STR 构造修复报告

**修复日期**: 2026-03-25
**修复人员**: Subagent (V2Ray Phase 9 JSON_STR Fix)
**任务阶段**: Phase 9 - 阶段 12

---

## 1. 问题描述

### 1.1 根本原因

VPS 验证发现 `JSON_STR` 构造错误：使用字符串拼接 `"\$(server),\$(stream)"` 而非 JSON 对象合并，导致 `--argjson` 解析失败。

### 1.2 问题表现

**错误构造**:
```bash
JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '"\($server),\($stream)"')
```

这会产生类似以下的无效 JSON:
```json
{"clients":[{"id":"uuid"}]},{"network":"h2","security":"tls"}
```

这是两个 JSON 对象的逗号分隔字符串，**不是有效 JSON**，无法被 `--argjson` 解析。

### 1.3 影响范围

影响以下协议的配置生成:
- Trojan-H2-TLS
- VLESS-gRPC-TLS
- VLESS-Reality
- 以及其他使用类似构造的协议

---

## 2. 问题位置

### 2.1 JSON_STR 构造错误（7 处）

| 行号 | 协议 | 网络类型 |
|------|------|----------|
| 1597 | Trojan/VLESS | h2/http |
| 1612 | Trojan/VLESS | kcp/mkcp |
| 1625 | Trojan/VLESS | quic |
| 1640 | Trojan/VLESS | ws/websocket |
| 1654 | Trojan/VLESS | grpc/gun |
| 1667 | Trojan/VLESS | h2/http |
| 1697 | Trojan/VLESS | reality |

### 2.2 第 452 行错误

**错误代码**:
```bash
IS_NEW_JSON=$(jq --argjson settings "{$JSON_STR}" --argjson sniffing "$IS_SNIFFING" ...)
```

**问题**: 在 `--argjson settings "{$JSON_STR}"` 中使用了不必要的大括号，导致 JSON_STR 被包装在额外的对象中。

---

## 3. 修复方案

### 3.1 JSON_STR 构造修复

**修复前**（错误 - 字符串拼接）:
```bash
JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '"\($server),\($stream)"')
```

**修复后**（正确 - JSON 对象合并）:
```bash
JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '$server + $stream')
```

**修复原理**:
- 使用 jq 的 `+` 操作符合并两个 JSON 对象
- 结果为单个有效的 JSON 对象，包含所有键值对

**示例**:
```bash
# 输入
IS_SERVER_ID_JSON='{"clients":[{"id":"test-uuid"}]}'
IS_STREAM='{"network":"h2","security":"tls"}'

# 输出（修复后）
JSON_STR='{"clients":[{"id":"test-uuid"}],"network":"h2","security":"tls"}'
```

### 3.2 第 452 行修复

**修复前**:
```bash
IS_NEW_JSON=$(jq --argjson settings "{$JSON_STR}" --argjson sniffing "$IS_SNIFFING" ...)
```

**修复后**:
```bash
IS_NEW_JSON=$(jq --argjson settings "$JSON_STR" --argjson sniffing "$IS_SNIFFING" ...)
```

**修复原理**:
- 移除 `{$JSON_STR}` 外围的大括号
- 直接传递 JSON_STR 对象，不进行额外包装

---

## 4. 修复前后代码对比

### 4.1 第 1597 行（示例）

**修复前**:
```bash
JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '"\($server),\($stream)"')
```

**修复后**:
```bash
JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '$server + $stream')
```

### 4.2 第 452 行

**修复前**:
```bash
IS_NEW_JSON=$(jq --argjson settings "{$JSON_STR}" --argjson sniffing "$IS_SNIFFING" \
    '{inbounds:[{tag:'\"$IS_CONFIG_NAME\"',port:'"$PORT"','"$IS_LISTEN"',protocol:'\"$IS_PROTOCOL\"', $settings, $sniffing}]}' <<<{})
```

**修复后**:
```bash
IS_NEW_JSON=$(jq --argjson settings "$JSON_STR" --argjson sniffing "$IS_SNIFFING" \
    '{inbounds:[{tag:'\"$IS_CONFIG_NAME\"',port:'"$PORT"','"$IS_LISTEN"',protocol:'\"$IS_PROTOCOL\"', $settings, $sniffing}]}' <<<{})
```

---

## 5. 验证结果

### 5.1 语法验证

```bash
cd /home/node/.openclaw/v2ray
bash -n src/core.sh
echo "语法检查退出码：$?"
```

**结果**: ✅ 通过（退出码 0）

### 5.2 修复位置验证

```bash
cd /home/node/.openclaw/v2ray
grep -n '\$server + \$stream' src/core.sh
```

**结果**: ✅ 所有 7 处已修复

```
1597:            JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '$server + $stream')
1612:            JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '$server + $stream')
1625:            JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '$server + $stream')
1640:            JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '$server + $stream')
1654:            JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '$server + $stream')
1667:            JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '$server + $stream')
1697:            JSON_STR=$($JQ -n --argjson server "$IS_SERVER_ID_JSON" --argjson stream "$IS_STREAM" '$server + $stream')
```

### 5.3 第 452 行验证

```bash
cd /home/node/.openclaw/v2ray
sed -n '450,455p' src/core.sh
```

**结果**: ✅ 已修复（移除大括号）

```bash
esac
        IS_SNIFFING=$(generate_sniffing)
        IS_NEW_JSON=$(jq --argjson settings "$JSON_STR" --argjson sniffing "$IS_SNIFFING" \
            '{inbounds:[{tag:'\"$IS_CONFIG_NAME\"',port:'"$PORT"','"$IS_LISTEN"',protocol:'\"$IS_PROTOCOL\"', $settings, $sniffing}]}' <<<{})
        if [[ $IS_DYNAMIC_PORT ]]; then
```

---

## 6. Git 提交

### 6.1 提交信息

```
fix(core.sh): 修复 JSON_STR 构造使用 jq + 操作合并对象

问题: JSON_STR 使用字符串拼接 "\$(server),\$(stream)" 导致无效 JSON
修复: 使用 jq + 操作合并 JSON 对象 \$server + \$stream
影响: 修复 Trojan-H2-TLS, VLESS-gRPC-TLS, VLESS-Reality 配置生成

修改:
- 7 处 JSON_STR 构造（第 1597, 1612, 1625, 1640, 1654, 1667, 1697 行）
- 第 452 行移除不必要的大括号

Refs: Phase 9 VPS 验证发现 JSON 构造错误
```

### 6.2 Commit 信息

- **Commit ID**: 14ce6ac
- **分支**: fix
- **推送**: origin/fix

### 6.3 文件变更统计

```
1 file changed, 8 insertions(+), 8 deletions(-)
```

---

## 7. 备份文件

| 文件 | 说明 |
|------|------|
| `src/core.sh.bak.20260325_json_str_fix` | 修复前完整备份 |

---

## 8. 验收标准检查

| 标准 | 状态 |
|------|------|
| ✅ 7 处 JSON_STR 构造全部修复（使用 + 操作） | 通过 |
| ✅ 第 452 行已修复（移除大括号） | 通过 |
| ✅ 语法检查通过 (`bash -n`) | 通过 |
| ✅ 本地测试 JSON 生成正确 | 通过 |
| ✅ Git 提交成功 | 通过 |
| ✅ 推送到 origin/fix | 通过 |

---

## 9. 后续建议

### 9.1 VPS 验证

建议在 VPS 上进行以下验证:

1. **Trojan-H2-TLS 配置生成测试**
2. **VLESS-gRPC-TLS 配置生成测试**
3. **VLESS-Reality 配置生成测试**

### 9.2 回归测试

建议运行完整的 Phase 9 测试套件，确保修复未引入新问题。

### 9.3 代码审查

建议审查其他可能使用类似字符串拼接构造 JSON 的代码位置。

---

## 10. 总结

本次修复解决了 V2Ray Phase 9 中 JSON_STR 构造的根本问题：

- **修复内容**: 7 处 JSON_STR 构造 + 1 处 jq 调用
- **修复方法**: 使用 jq `+` 操作符合并 JSON 对象
- **影响协议**: 所有使用 server + stream 模式的协议
- **验证状态**: 全部通过

修复已完成并推送到 `origin/fix` 分支。

---

**报告结束**