# T5: 修复 SSL 验证测试用例

> 任务: 移除 `_wget()` 中默认的 `--no-check-certificate`，添加 TLS 1.2+ 强制验证
> 创建时间: 2026-04-07
> 状态: ✅ 已完成
> 负责人: -

---

## 背景

`_wget()` 函数全局使用 `--no-check-certificate`，禁用 SSL 证书验证，存在中间人攻击风险。

---

## 测试用例总览

| 用例 ID | 测试类型 | 测试内容 | 优先级 |
|---------|----------|----------|--------|
| TC-01 | 代码扫描 | `install.sh` 无 `--no-check-certificate` | 🔴 P0 |
| TC-02 | 代码扫描 | `src/init.sh` 无 `--no-check-certificate` | 🔴 P0 |
| TC-03 | 功能测试 | 正常 HTTPS 下载验证证书 | 🔴 P0 |
| TC-04 | 功能测试 | GitHub Release 下载成功 | 🔴 P0 |
| TC-05 | 功能测试 | Cloudflare API 下载成功 | 🔴 P0 |
| TC-06 | 边界测试 | 无效证书时下载失败 | 🟡 P1 |
| TC-07 | 边界测试 | `--insecure` 可选参数支持 | 🟡 P1 |
| TC-08 | 回归测试 | SHA256 校验仍然正常 | 🔴 P0 |

---

## TC-01 ~ TC-02: 代码扫描

| 用例 ID | 目标文件 | 验证命令 |
|---------|----------|----------|
| TC-01 | `install.sh` | `grep -n 'no-check-certificate' install.sh` |
| TC-02 | `src/init.sh` | `grep -n 'no-check-certificate' src/init.sh` |

### 预期结果

```
✅ 无 --no-check-certificate 出现在用户可见代码中
✅ 使用 --secure-protocol=TLSv1_2 或默认验证
```

---

## TC-03: 正常 HTTPS 下载验证证书

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | 服务器可访问互联网 |
| **测试目标** | 验证正常 HTTPS 下载时证书被验证 |

### 测试步骤

```bash
wget -q -O /dev/null https://github.com 2>&1
# 不应出现 "WARNING: cannot verify" 警告
```

### 预期结果

```
✅ 下载成功
✅ 无证书验证警告
```

---

## TC-04: GitHub Release 下载成功

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **测试目标** | 验证 GitHub Release 下载正常工作 |

### 预期结果

```
✅ Xray-core 下载成功
✅ 证书验证通过
```

---

## TC-05: Cloudflare API 下载成功

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **测试目标** | 验证 Cloudflare API 下载正常工作 |

### 预期结果

```
✅ IP 获取成功
✅ 证书验证通过
```

---

## TC-06: 无效证书时下载失败

| 字段 | 内容 |
|------|------|
| **优先级** | 🟡 P1 |
| **测试目标** | 验证无效证书导致下载失败 |

### 测试步骤

```bash
wget -q -O /dev/null https://expired.badssl.com/ 2>&1
echo "退出码: $?"
```

### 预期结果

```
✅ 退出码 ≠ 0
✅ 出现证书错误提示
```

---

## TC-07: --insecure 可选参数支持

| 字段 | 内容 |
|------|------|
| **优先级** | 🟡 P1 |
| **测试目标** | 验证需要时可手动传入 --no-check-certificate |

### 预期结果

```
✅ _wget --no-check-certificate https://expired.badssl.com/ 可绕过验证
```

---

## TC-08: SHA256 校验仍然正常

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **测试目标** | 验证 T4 SHA256 校验不受影响 |

### 预期结果

```
✅ Xray-core 下载 + 校验通过
```

---

## 测试结果汇总

| 用例 ID | 测试结果 | 执行时间 | 执行者 | 备注 |
|---------|----------|----------|--------|------|
| TC-01 | ✅ 通过 | 2026-04-07 | Qwen | install.sh 无 `--no-check-certificate` |
| TC-02 | ✅ 通过 | 2026-04-07 | Qwen | src/init.sh 无 `--no-check-certificate` |
| TC-03 | ✅ 通过 | 2026-04-07 | Qwen | GitHub HTTPS 下载成功, 证书验证通过 |
| TC-04 | ✅ 通过 | 2026-04-07 | Qwen | .dgst 下载成功 |
| TC-05 | ✅ 通过 | 2026-04-07 | Qwen | Cloudflare API 访问成功 |
| TC-06 | ✅ 通过 | 2026-04-07 | Qwen | 无效证书 (expired.badssl.com) 导致失败, TLS 1.2 验证生效 |
| TC-07 | ✅ 通过 | 2026-04-07 | Qwen | 手动传入 `--no-check-certificate` 可绕过 |
| TC-08 | ✅ 通过 | 2026-04-07 | Qwen | Xray-core 下载 + SHA256 校验通过 (T4 不受影响) |

---

*文档创建: 2026-04-07 | 状态: ✅ 已完成 | 8/8 全部通过 | 测试时间: 2026-04-07 | 服务器: 测试服务器*
