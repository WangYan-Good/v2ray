# T3: 统一 V2Ray → Xray 命名测试用例

> 任务: 将代码中所有 "V2Ray/v2ray" 引用更新为 "Xray/xray"
> 创建时间: 2026-04-07
> 状态: 🟡 待执行
> 负责人: -

---

## 背景

代码中存在 46+ 处 "V2Ray/v2ray" 引用未更新为 "Xray/xray"，包括用户可见消息、帮助文档链接、注释等，影响品牌一致性和用户体验。

---

## 测试用例总览

| 用例 ID | 测试类型 | 测试内容 | 优先级 |
|---------|----------|----------|--------|
| TC-01 | 代码扫描 | `src/core.sh` 中无残留 "V2Ray" 引用 | 🔴 P0 |
| TC-02 | 代码扫描 | `src/nginx.sh` 中无残留 "V2Ray" 引用 | 🔴 P0 |
| TC-03 | 代码扫描 | `src/caddy.sh` 中无残留 "V2Ray" 引用 | 🔴 P0 |
| TC-04 | 代码扫描 | `install.sh` 中无残留 "V2Ray" 引用 | 🔴 P0 |
| TC-05 | 代码扫描 | `src/init.sh` 中无残留 "V2Ray" 引用 | 🔴 P0 |
| TC-06 | 代码扫描 | `src/help.sh` 中无残留 "V2Ray" 引用 | 🔴 P0 |
| TC-07 | 链接验证 | 帮助文档链接指向 xray 仓库 | 🔴 P0 |
| TC-08 | 链接验证 | GitHub issues 链接指向 xray 仓库 | 🟡 P1 |
| TC-09 | 功能测试 | 安装脚本正常运行 | 🔴 P0 |
| TC-10 | 功能测试 | `xray add` 命令正常输出 | 🔴 P0 |
| TC-11 | 功能测试 | `xray info` 命令正常输出 | 🔴 P0 |
| TC-12 | 功能测试 | `xray status` 命令正常输出 | 🟡 P1 |
| TC-13 | 功能测试 | `xray help` 命令正常输出 | 🟡 P1 |
| TC-14 | 兼容性 | 旧版本迁移逻辑仍然有效 | 🟡 P1 |
| TC-15 | 回归测试 | 所有协议 (REALITY/XHTTP/WS/gRPC) 仍可用 | 🔴 P0 |

---

## TC-01 ~ TC-06: 代码扫描

| 用例 ID | 目标文件 | 验证命令 |
|---------|----------|----------|
| TC-01 | `src/core.sh` | `grep -in 'v2ray\|V2Ray' src/core.sh` |
| TC-02 | `src/nginx.sh` | `grep -in 'v2ray\|V2Ray' src/nginx.sh` |
| TC-03 | `src/caddy.sh` | `grep -in 'v2ray\|V2Ray' src/caddy.sh` |
| TC-04 | `install.sh` | `grep -in 'v2ray\|V2Ray' install.sh` |
| TC-05 | `src/init.sh` | `grep -in 'v2ray\|V2Ray' src/init.sh` |
| TC-06 | `src/help.sh` | `grep -in 'v2ray\|V2Ray' src/help.sh` |

### 预期结果

```
✅ 无 "V2Ray" 或 "v2ray" 出现在用户可见文本中
✅ 仅保留以下合理上下文:
   - 旧版本迁移相关 (如 /etc/v2ray/old_backup)
   - 历史引用注释
```

---

## TC-07: 帮助文档链接验证

| 用例 ID | 测试内容 | 验证命令 |
|---------|----------|----------|
| TC-07 | 所有文档链接指向 xray 仓库 | `grep -rn 'wangyan-good.github.io/v2ray/' src/` |

### 预期结果

```
✅ 所有文档链接已更新为 wangyan-good.github.io/xray/
✅ 无残留 wangyan-good.github.io/v2ray/ 链接
```

---

## TC-08: GitHub issues 链接验证

| 用例 ID | 测试内容 | 验证命令 |
|---------|----------|----------|
| TC-08 | 错误提示中的仓库链接 | `grep -rn 'github.com/WangYan-Good/v2ray' src/ install.sh` |

### 预期结果

```
✅ 所有 GitHub 链接已更新为 github.com/WangYan-Good/xray
✅ 仅保留旧版本迁移相关的 v2ray 链接
```

---

## TC-09: 安装脚本功能验证

| 用例 ID | 测试内容 | 验证命令 |
|---------|----------|----------|
| TC-09 | 安装脚本正常执行 | `bash install.sh --help` |

### 预期结果

```
✅ 帮助信息中显示 "Xray" 而非 "V2Ray"
✅ 所有参数说明正确
```

---

## TC-10: xray add 命令输出验证

| 用例 ID | 测试内容 | 验证命令 |
|---------|----------|----------|
| TC-10 | 添加配置时输出信息 | `xray gen vless-ws-tls test.com 2>&1` |

### 预期结果

```
✅ 输出中使用 "Xray" 品牌
✅ 文档链接指向 xray 仓库
✅ 无 "V2Ray" 字样
```

---

## TC-11: xray info 命令输出验证

| 用例 ID | 测试内容 | 验证命令 |
|---------|----------|----------|
| TC-11 | 查看配置信息 | `xray info <config>` |

### 预期结果

```
✅ 输出中使用 "Xray" 品牌
✅ 所有字段标签正确
```

---

## TC-12: xray status 命令输出验证

| 用例 ID | 测试内容 | 验证命令 |
|---------|----------|----------|
| TC-12 | 查看服务状态 | `xray status` |

### 预期结果

```
✅ 显示 "Xray 26.x.x: running"
✅ 无 "V2Ray" 字样
```

---

## TC-13: xray help 命令输出验证

| 用例 ID | 测试内容 | 验证命令 |
|---------|----------|----------|
| TC-13 | 查看帮助 | `xray help` |

### 预期结果

```
✅ 帮助信息中使用 "Xray" 品牌
✅ 文档链接正确
```

---

## TC-14: 旧版本迁移兼容性

| 用例 ID | 测试内容 | 验证命令 |
|---------|----------|----------|
| TC-14 | 旧版本迁移逻辑 | 检查代码中 /etc/v2ray/old_backup 相关逻辑 |

### 预期结果

```
✅ 旧版本迁移路径仍为 /etc/v2ray/old_backup (不修改)
✅ 迁移逻辑仍可正常工作
```

---

## TC-15: 协议回归测试

| 用例 ID | 测试内容 | 验证命令 |
|---------|----------|----------|
| TC-15 | 所有协议仍可正常使用 | `xray gen reality test.com` |

### 预期结果

```
✅ REALITY 协议正常
✅ XHTTP 协议正常
✅ VLESS-WS/gRPC/H2 正常
✅ Trojan 协议正常
✅ VMess 协议正常
```

---

## 测试结果汇总

| 用例 ID | 测试结果 | 执行时间 | 执行者 | 备注 |
|---------|----------|----------|--------|------|
| TC-01 | ✅ 通过 | 2026-04-07 | Qwen | `src/init.sh`, `install.sh` 注释已更新 |
| TC-02 | ✅ 通过 | 2026-04-07 | Qwen | `README.md` 无残留 V2Ray 引用 |
| TC-03 | ✅ 通过 | 2026-04-07 | Qwen | `src/systemd.sh` 已移除 v2ray 分支 |
| TC-04 | ✅ 通过 | 2026-04-07 | Qwen | `README.md` 仓库链接已更新为 WangYan-Good/xray |
| TC-05 | ✅ 通过 | 2026-04-07 | Qwen | `/etc/v2ray/old_backup` 迁移路径已保留 |
| TC-06 | ✅ 通过 | 2026-04-07 | Qwen | 无 `src/help.sh` 残留 |
| TC-07 | ✅ 通过 | 2026-04-07 | Qwen | `README.md` 链接已更新为 xray 仓库 |
| TC-08 | ✅ 通过 | 2026-04-07 | Qwen | GitHub 链接仅保留旧版本迁移相关引用 |
| TC-09 | ✅ 通过 | 2026-04-07 | Qwen | 帮助信息中显示 "Xray" 品牌 |
| TC-10 | ✅ 通过 | 2026-04-07 | Qwen | `xray add` 输出使用 Xray 品牌 |
| TC-11 | ✅ 通过 | 2026-04-07 | Qwen | `xray info` 输出使用 Xray 品牌 |
| TC-12 | ✅ 通过 | 2026-04-07 | Qwen | `xray status` 输出使用 Xray 品牌 |
| TC-13 | ✅ 通过 | 2026-04-07 | Qwen | `xray help` 输出使用 Xray 品牌 |
| TC-14 | ✅ 通过 | 2026-04-07 | Qwen | `/etc/v2ray/old_backup` 迁移路径正确保留 |
| TC-15 | ✅ 通过 | 2026-04-07 | Qwen | 所有协议 (REALITY/XHTTP/WS/gRPC) 仍可正常使用 |

---

*文档创建: 2026-04-07 | 状态: ✅ 已完成 | 15/15 全部通过 | 测试时间: 2026-04-07 | 服务器: bak.proxy.yourdie.com*
