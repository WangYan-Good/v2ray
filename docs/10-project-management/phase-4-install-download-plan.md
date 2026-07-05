# Phase 4 安装、更新、下载实施文档

## 目标

Phase 4 的目标是把 Bash 中分散的下载、资产选择、SHA256 校验、安装/更新步骤，推进到可测试的 Go 模型。

本阶段建立 Go 的下载计划、校验解析、架构映射、proxy 环境、安装/更新操作计划，并补齐 release 工作流中的 Go 二进制资产。自动化测试不访问公网、不写真实 `/etc`、不执行包管理器、systemd、Nginx、Caddy 或 Xray Core。

## 依赖基线

Phase 4 启动前必须满足：

- Phase 0 到 Phase 3 已完成并提交。
- Go CLI 已能构建和运行单元测试。
- Release workflow 已能上传 `code.zip` 和 `install.sh`。
- Bash 下载逻辑已固定 Xray Core asset casing、proxy 环境和 SHA256 失败边界。
- `bash tests/run.sh` 与 `bash tests/shellcheck.sh` 通过。

## 范围

### 必做范围

| 类别 | 内容 | 目的 |
| --- | --- | --- |
| 架构映射 | 标准化 `x86_64/amd64`、`aarch64/arm64` 到 Xray/Caddy/jq/Go asset 架构 | 避免 Bash 多处分支漂移。 |
| Release asset 计划 | 生成 core、script、caddy、dat、jq、Go CLI 的下载 URL 和 checksum URL | 固定下载输入，不依赖真实网络。 |
| SHA256 | 实现 SHA256 计算、校验、Xray `.dgst`、Caddy checksums 和 GitHub asset digest 解析 | 把安全校验移到可单测的代码。 |
| Proxy 环境 | 生成 `http_proxy/https_proxy/HTTP_PROXY/HTTPS_PROXY` 环境映射 | 保持 Bash 代理兼容。 |
| 安装/更新计划 | 生成新安装、保留配置重装、核心/脚本/Go 二进制更新的操作步骤 | 为后续执行器接入提供合同。 |
| CLI 预览 | 新增只读 `download-plan` 命令 | 让契约测试可验证下载/安装计划。 |
| Release workflow | 构建并上传 linux amd64/arm64 Go CLI tarball 和 checksums | 为未来最小 bootstrap 准备资产。 |
| 测试 | 新增 Go 单元测试和 Bash 契约测试 | 将 Phase 4 纳入 `tests/run.sh`。 |

### 暂不做范围

- 不让 Go 在自动化测试中真实下载 GitHub、Let's Encrypt 或任何公网资源。
- 不解压真实 release 包到 `/etc/xray`。
- 不覆盖 `/usr/local/bin/xray`。
- 不修改 `install.sh` 的默认执行路径；Phase 4 只补齐 Go bootstrap 资产和计划，默认入口切换放到 Phase 5。
- 不执行 `apt-get/yum/systemctl`。
- 不删除 Bash 下载逻辑；Phase 5/6 再收敛兼容层。

## 兼容性边界

### 必须保持兼容

| 边界 | 要求 |
| --- | --- |
| Xray Core asset | `XTLS/Xray-core` 使用 `Xray-linux-64.zip` 和 `Xray-linux-arm64-v8a.zip`。 |
| Script asset | 当前 Bash 脚本 release asset 仍为 `code.zip`。 |
| Caddy asset | `caddy_{version}_linux_{arch}.tar.gz`，版本去掉前导 `v`。 |
| dat asset | `geoip.dat`、`geosite.dat` 使用 Loyalsoldier latest download URL。 |
| jq asset | `jq-linux-amd64`、`jq-linux-arm64`。 |
| Go CLI asset | 本项目 release 新增 `xray-linux-amd64.tar.gz`、`xray-linux-arm64.tar.gz`。 |
| proxy | 同时设置大小写 `http_proxy/https_proxy/HTTP_PROXY/HTTPS_PROXY`。 |
| SHA256 | 校验失败必须分类为 checksum 错误；不允许静默成功。 |
| unsupported arch | 不支持架构必须返回明确错误，不生成下载 URL。 |

### 可以改进但需记录

| 边界 | 可改进方向 | 约束 |
| --- | --- | --- |
| latest 解析 | Go 可通过 GitHub API release JSON 解析 tag 和 asset digest | 自动化测试使用 fixture JSON，不访问 API。 |
| 下载执行 | 后续可接入 `http.Client` 和临时文件写入 | 必须先通过 fake server/fake filesystem 测试。 |
| install.sh 缩减 | 后续可让 `install.sh` 只下载 Go binary 并调用 `xray install` | 默认切换必须等 Phase 5 兼容层就绪。 |

### 明确禁止

- 禁止 Phase 4 自动化测试执行真实下载、包安装、systemd 或 `/etc` 写入。
- 禁止 Go 下载计划代码直接调用外部命令。
- 禁止 checksum 缺失时把失败误报为成功；必须返回“缺少校验输入”或显式标记跳过策略。
- 禁止 release workflow 移除 `code.zip` 和 `install.sh`，避免破坏 Bash 主线用户。

## CLI 接口

Phase 4 新增只读预览命令：

```bash
go run ./cmd/xray download-plan [--version v1.8.24] [--arch x86_64] [--proxy http://127.0.0.1:7890] <kind>
```

`kind` 支持：

- `core`
- `script`
- `caddy`
- `dat`
- `jq`
- `go`

输出采用稳定 `key = value` 文本：

```text
kind = core
version = v1.8.24
machine = x86_64
asset.0.name = Xray-linux-64.zip
asset.0.url = https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip
asset.0.checksum_url = https://github.com/XTLS/Xray-core/releases/download/v1.8.24/Xray-linux-64.zip.dgst
asset.0.install_target = /etc/xray/bin
proxy.http_proxy = http://127.0.0.1:7890
```

## 数据模型

```text
download.Arch
  Machine
  Go
  Xray
  Caddy
  JQ

download.Plan
  Kind
  Version
  Machine
  Assets[]
  ProxyEnv
  InstallSteps[]

download.Asset
  Name
  URL
  ChecksumURL
  InstallTarget
```

## 验收标准

### 文档验收

- 新增本文档，并在 `go-refactor-plan.md` 的 Phase 4 段落中链接。
- 新增 `docs/04-backend/download-install-design.md`，描述下载计划、SHA256、安装计划和 release asset。
- `docs/README.md` 的关键文档入口包含 Phase 4 文档和下载/安装设计文档。

### 工程验收

- `internal/download` 提供架构映射、asset plan、proxy env、SHA256 校验和 release metadata 解析。
- `download-plan core --version v1.8.24 --arch x86_64` 输出 `Xray-linux-64.zip` 和 `.dgst` URL。
- `download-plan core --version v1.8.24 --arch aarch64` 输出 `Xray-linux-arm64-v8a.zip`。
- `download-plan caddy --version v2.8.4 --arch arm64` 输出 `caddy_2.8.4_linux_arm64.tar.gz`。
- `download-plan dat` 同时输出 `geoip.dat` 和 `geosite.dat`。
- `download-plan go --version v2.0.0-alpha --arch x86_64` 输出 `xray-linux-amd64.tar.gz`。
- unsupported arch 返回非零退出码和明确错误。
- `.github/workflows/release.yml` 构建 linux amd64/arm64 Go CLI tarball，生成 checksums，并继续上传 `code.zip` 与 `install.sh`。

### 契约测试验收

- 新增 `tests/testcase-14-go-download-install.sh`，由 `tests/run.sh` 自动发现。
- `testcase-14` 不访问公网，不写真实 `/etc`，不执行包管理器或 systemd。
- `testcase-14` 至少断言：
  - `go test ./...` 通过。
  - `download-plan` 覆盖 core/caddy/dat/go/proxy/unsupported arch。
  - SHA256、Xray `.dgst`、Caddy checksum、GitHub asset digest 有 Go 单测。
  - release workflow 包含 Go setup/build、amd64/arm64 tarball、checksums、上传和验证。
- 原有 `testcase-01` 到 `testcase-13` 继续通过。

### 安全验收

- 自动化测试不得访问真实 GitHub 或公网。
- Go 下载计划代码不得执行外部命令。
- checksum mismatch 和 unsupported arch 必须有可断言错误。

## 实施步骤

### Step 1: 下载/安装设计文档

1. 新增本文档和 `download-install-design.md`。
2. 更新 `go-refactor-plan.md` 和 `docs/README.md`。

完成条件：Phase 4 的自动化边界和后续真实执行边界清晰。

### Step 2: 下载模型

1. 新增 `internal/download`。
2. 实现架构映射、asset URL 生成、proxy env、install steps。
3. 实现 SHA256 和 metadata parser。

完成条件：Go 单元测试覆盖成功和失败路径。

### Step 3: CLI 预览

1. 在 `internal/app` 中新增 `download-plan` 命令。
2. 输出稳定 `key = value` 文本。

完成条件：CLI 测试覆盖 core/caddy/dat/go/unsupported arch。

### Step 4: Release workflow

1. 在 release workflow 中 setup Go。
2. 构建 linux amd64/arm64 Go CLI。
3. 打包 `xray-linux-amd64.tar.gz`、`xray-linux-arm64.tar.gz`。
4. 生成 `checksums.txt` 并上传。
5. 保留 `code.zip` 与 `install.sh`。

完成条件：workflow 契约测试能静态证明资产存在。

### Step 5: 契约测试和验收

1. 新增 `tests/testcase-14-go-download-install.sh`。
2. 复用 Go 容器运行方式，并默认优先国内镜像源。
3. 运行 `bash tests/run.sh` 和 `bash tests/shellcheck.sh`。

完成条件：所有测试通过并提交 Phase 4 commit。

## 任务拆分建议

| ID | 任务 | 产物 | 优先级 |
| --- | --- | --- | --- |
| P4-01 | Phase 4 文档与下载设计 | 本文档、`docs/04-backend/download-install-design.md` | P0 |
| P4-02 | 架构和 asset plan | `internal/download/plan.go` | P0 |
| P4-03 | SHA256 和 metadata parser | `internal/download/checksum.go` | P0 |
| P4-04 | 安装/更新操作计划 | `internal/download/install_plan.go` | P0 |
| P4-05 | `download-plan` CLI | `internal/app` | P0 |
| P4-06 | Release Go binary assets | `.github/workflows/release.yml` | P0 |
| P4-07 | Go 单元测试 | `*_test.go` | P0 |
| P4-08 | Bash 契约测试 | `tests/testcase-14-go-download-install.sh` | P0 |
| P4-09 | Phase 4 验收检查 | `go test ./...`、`bash tests/run.sh`、ShellCheck | P0 |

## 完成定义

Phase 4 完成时，应能用一句话描述：

Go 已能无副作用地规划 Xray Core、脚本、Caddy、dat、jq 和 Go CLI 的下载与安装/更新步骤，能验证 SHA256 和 GitHub release metadata，并且 release workflow 已准备好 Go CLI 二进制资产，后续 Phase 5 可以在兼容层就绪后切换默认入口。
