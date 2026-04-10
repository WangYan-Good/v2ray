# T19: CI/CD 流水线测试用例

> 任务: 引入 GitHub Actions CI/CD 流水线，自动运行代码检查和测试
> 创建时间: 2026-04-10
> 状态: ⬜ 开发中
> 负责人: -

---

## 背景

项目缺乏自动化 CI/CD 流程，每次代码修改后需手动验证，效率低且易遗漏问题。

**T19 目标**:
1. 创建 `.github/workflows/ci.yml`，在 push/PR 时自动触发
2. 使用 ShellCheck 扫描所有 `.sh` 文件
3. 运行基础功能测试 (协议配置生成、JSON 验证)
4. 验证安装脚本语法正确性

---

## 测试用例总览

| 用例 ID | 测试类型 | 测试内容 | 优先级 |
|---------|----------|----------|--------|
| TC-01 | CI 功能 | ShellCheck 扫描所有 .sh 文件 | 🔴 P0 |
| TC-02 | CI 功能 | 安装脚本语法验证 (bash -n) | 🔴 P0 |
| TC-03 | CI 功能 | JSON 配置文件格式验证 | 🔴 P0 |
| TC-04 | CI 功能 | 协议列表完整性检查 | 🟡 P1 |
| TC-05 | CI 功能 | 命名一致性检查 (无 V2Ray 残留) | 🔴 P0 |
| TC-06 | CI 集成 | PR 触发 CI 流水线 | 🔴 P0 |
| TC-07 | CI 集成 | push 到 develop 分支触发 | 🔴 P0 |
| TC-08 | CI 集成 | CI 失败时正确报告 | 🟡 P1 |
| TC-09 | 回归测试 | 现有 release.yml 不受影响 | 🔴 P0 |
| E2E-01 | 端到端 | 完整 CI 流程: push → check → report | 🔴 P0 |

---

## TC-01: ShellCheck 扫描所有 .sh 文件

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **测试目标** | 验证 CI 流水线能正确运行 ShellCheck 并报告问题 |

### CI 步骤

```yaml
- name: ShellCheck
  run: |
    sudo apt-get update && sudo apt-get install -y shellcheck
    shellcheck --severity=info install.sh xray.sh src/*.sh
```

### 预期结果

```
✅ 所有 .sh 文件通过扫描
✅ SC2086/SC2154 零报错
✅ 如有问题，CI 失败并输出具体行号和修复建议
```

---

## TC-02: 安装脚本语法验证

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **测试目标** | 验证 install.sh 和所有 .sh 文件语法正确 |

### CI 步骤

```yaml
- name: Bash syntax check
  run: |
    bash -n install.sh
    bash -n xray.sh
    for f in src/*.sh; do bash -n "$f"; done
```

### 预期结果

```
✅ 所有文件语法正确，无 syntax error
✅ 如有语法错误，CI 失败并输出错误位置
```

---

## TC-03: JSON 配置文件格式验证

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **测试目标** | 验证项目中任何 JSON 配置文件格式正确 |

### CI 步骤

```yaml
- name: JSON validation
  run: |
    sudo apt-get install -y jq
    # 验证项目中无损坏的 JSON 文件
    find . -name "*.json" -not -path "./.git/*" -exec jq . {} \; >/dev/null
```

### 预期结果

```
✅ 所有 JSON 文件可被 jq 正确解析
✅ 如有非法 JSON，CI 失败
```

---

## TC-04: 协议列表完整性检查

| 字段 | 内容 |
|------|------|
| **优先级** | 🟡 P1 |
| **测试目标** | 验证 protocol_list 包含所有预期协议 |

### CI 步骤

```bash
# 检查关键协议是否存在
grep -q 'VLESS-XTLS-uTLS-REALITY' src/core.sh
grep -q 'VLESS-XHTTP-TLS' src/core.sh
grep -q 'Trojan-XHTTP-TLS' src/core.sh
grep -q 'VMess-WS-TLS' src/core.sh
```

### 预期结果

```
✅ 所有关键协议存在于 protocol_list
✅ 无注释掉的协议声明
```

---

## TC-05: 命名一致性检查

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **测试目标** | 确保无 V2Ray/v2ray 品牌残留 |

### CI 步骤

```bash
# 检查用户可见文本中无 V2Ray
grep -rn 'V2Ray\|v2ray' src/ install.sh \
  --include="*.sh" | grep -v 'old_backup\|Loyalsoldier\|tree/old' && exit 1 || exit 0
```

### 预期结果

```
✅ 零残留 (除合理上下文: old_backup, Loyalsoldier, tree/old)
✅ 如有残留，CI 失败
```

---

## TC-06: PR 触发 CI 流水线

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **测试目标** | 创建 PR 时自动触发 CI 检查 |

### 预期结果

```
✅ PR 页面显示 CI 检查状态
✅ 所有检查通过后显示绿色 ✓
✅ 如检查失败，PR 页面显示红色 ✗ 和详细日志链接
```

---

## TC-07: push 到 develop 分支触发

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **测试目标** | push 到 develop 分支时自动触发 CI |

### CI 触发条件

```yaml
on:
  push:
    branches: [develop, main, master]
  pull_request:
    branches: [develop]
```

### 预期结果

```
✅ push 到 develop 后立即触发 CI
✅ Actions 页面显示运行记录
```

---

## TC-08: CI 失败时正确报告

| 字段 | 内容 |
|------|------|
| **优先级** | 🟡 P1 |
| **测试目标** | 验证 CI 失败时提供清晰的错误信息 |

### 测试方法

```bash
# 人为引入一个 ShellCheck 错误 (SC2086)
# 提交到测试分支，观察 CI 失败报告
```

### 预期结果

```
✅ CI 状态显示 failure (红色)
✅ 错误日志包含具体文件、行号和错误类型
✅ PR/commit 页面可直接点击查看失败日志
```

---

## TC-09: 现有 release.yml 不受影响

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **测试目标** | 验证新增 ci.yml 不干扰现有 release 流程 |

### 验证方法

```bash
# 确认 release.yml 触发条件不变
grep -A5 'on:' .github/workflows/release.yml
# 应仅响应 tag push
```

### 预期结果

```
✅ release.yml 仅在 push tag 时触发
✅ ci.yml 不影响 release 流程
```

---

## E2E-01: 完整 CI 流程端到端测试

| 字段 | 内容 |
|------|------|
| **优先级** | 🔴 P0 |
| **前置条件** | ci.yml 已创建并推送 |
| **测试目标** | 验证 push → CI 触发 → 检查运行 → 结果报告的完整流程 |

### 测试步骤

```bash
# 1. 创建测试分支
git checkout -b test/ci-pipeline develop

# 2. 修改一个文件 (如添加注释)
echo '# CI test comment' >> README.md
git add README.md && git commit -m "test: trigger CI"
git push origin test/ci-pipeline

# 3. 观察 GitHub Actions
# - Actions 页面应显示运行中的 workflow
# - 所有 jobs 应通过 (绿色 ✓)

# 4. 创建 PR
# - PR 页面应显示 CI 检查状态
# - 所有检查通过后应显示绿色 ✓

# 5. 清理测试分支
git push origin --delete test/ci-pipeline
```

### 预期结果

```
✅ CI 在 push 后 30s 内自动触发
✅ 所有 jobs 成功通过
✅ ShellCheck 无 SC2086/SC2154 错误
✅ bash -n 语法检查通过
✅ 命名一致性检查通过
✅ PR 检查状态正确显示
```

---

## CI 流水线设计

### 工作流名称: `ci.yml`

```
┌─────────────────────────────────────────┐
│           CI Check (Ubuntu)             │
├─────────────────────────────────────────┤
│ Step 1: Checkout code                   │
│ Step 2: Install shellcheck + jq         │
│ Step 3: ShellCheck (SC2086/SC2154)      │
│ Step 4: Bash syntax check (bash -n)     │
│ Step 5: JSON validation (jq)            │
│ Step 6: Naming consistency check        │
│ Step 7: Protocol list completeness      │
└─────────────────────────────────────────┘
         │                    │
    ✅ All Pass           ❌ Any Fail
         │                    │
    PR ✓ Green         PR ✗ Red + log link
```

### 触发条件

| 事件 | 分支 | 行为 |
|------|------|------|
| push | develop, main, master | 运行 CI |
| pull_request | develop | 运行 CI + 报告状态 |

### 预期运行时间

| Step | 预计耗时 |
|------|---------|
| Checkout | 5s |
| Install deps | 15s |
| ShellCheck | 10s |
| bash -n | 3s |
| JSON validation | 5s |
| Naming check | 3s |
| Protocol check | 3s |
| **总计** | **~44s** |

---

## 测试结果汇总

| 用例 ID | 测试结果 | 执行时间 | 执行者 | 备注 |
|---------|----------|----------|--------|------|
| TC-01 | ⬜ | - | - | - |
| TC-02 | ⬜ | - | - | - |
| TC-03 | ⬜ | - | - | - |
| TC-04 | ⬜ | - | - | - |
| TC-05 | ⬜ | - | - | - |
| TC-06 | ⬜ | - | - | - |
| TC-07 | ⬜ | - | - | - |
| TC-08 | ⬜ | - | - | - |
| TC-09 | ⬜ | - | - | - |
| E2E-01 | ⬜ | - | - | - |

---

*文档创建: 2026-04-10 | 状态: 待执行*
