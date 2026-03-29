# CI/CD 配置完成指南

## GitHub Actions 配置

### 配置文件位置

`.github/workflows/test.yml`

### 功能说明

1. **触发条件**
   - 推送到 `master` 或 `develop` 分支
   - Pull Request 到 `master` 或 `develop` 分支
   - 手动触发 (`workflow_dispatch`)

2. **测试流程**
   - 检出代码
   - 设置 Python 3.11 环境
   - 安装 pytest 和 pytest-html
   - 运行 pytest 测试
   - 上传测试报告
   - 运行 bash 测试
   - 检查测试结果

3. **测试报告**
   - HTML 报告：`report.html`
   - 日志文件：`/tmp/v2ray-pytest.log`
   - 保留天数：7 天

### 使用方法

1. **推送到分支**
   ```bash
   git push origin master
   ```

2. **创建 Pull Request**
   ```bash
   git push origin feature-branch
   # 在 GitHub 创建 PR
   ```

3. **手动触发**
   - 在 GitHub 仓库页面
   - 点击 "Actions" 标签
   - 选择 "Caddy Validation Tests"
   - 点击 "Run workflow"

### 本地测试

```bash
# 安装 pytest
pip install pytest pytest-html

# 运行测试
pytest tests/ -v

# 生成 HTML 报告
pytest tests/ -v --html=report.html --self-contained-html
```

---

## GitLab CI/CD 配置（可选）

如果使用 GitLab，创建 `.gitlab-ci.yml`:

```yaml
stages:
  - test

variables:
  V2RAY_ENV: "testing"
  LOG_FILE: "/tmp/v2ray-pytest.log"

test:
  stage: test
  image: python:3.11-slim
  
  before_script:
    - apt-get update && apt-get install -y bash
    - pip install pytest pytest-html
    - bash -c "source caddy-validation-optimizer.sh || true"
  
  script:
    - pytest tests/ -v --tb=short --html=report.html
    - bash test-caddy-validation.sh || echo "Bash tests completed"
  
  artifacts:
    reports:
      junit: pytest-results.xml
    paths:
      - report.html
    expire_in: 7 days
  
  rules:
    - if: '$CI_COMMIT_BRANCH == "master" || $CI_COMMIT_BRANCH == "develop"'
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

---

## 测试结果期望

### pytest 测试

```
tests/test_environment_consistency.py .......  [ 12%]
tests/test_auto_correct.py .....             [ 22%]
tests/test_diagnosis.py ......               [ 33%]
tests/test_override_flags.py ......          [ 44%]
tests/test_edge_cases.py .....               [ 54%]
tests/test_logging.py .....                  [ 64%]
tests/test_permissions.py .....              [ 75%]
tests/test_parameter_combinations.py ......  [ 86%]
tests/test_non_interactive.py .....          [ 96%]
tests/test_e2e.py ......                     [100%]

======================== 52 passed in 10.00s ========================
```

### Bash 测试

```
=== 测试结果 ===
通过: 30
失败: 0
总计: 30

所有测试通过！
```

---

## 问题排查

### 测试失败

1. **检查 Python 环境**
   ```bash
   python --version
   pip list | grep pytest
   ```

2. **运行调试模式**
   ```bash
   pytest tests/ -vv
   ```

3. **查看测试日志**
   ```bash
   cat /tmp/v2ray-pytest.log
   ```

### GitHub Actions 失败

1. **查看 Action 日志**
   - GitHub 仓库 → Actions 标签
   - 点击失败的运行 → 查看详细日志

2. **检查权限**
   - 确保仓库有 Actions 权限
   - 检查 secrets 配置

3. **重试运行**
   - 在 Actions 页面点击 "Re-run jobs"

---

## 代码质量保证

### 预提交钩子（可选）

创建 `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
```

### 代码审查要求

- 所有代码必须通过测试
- 新增功能必须有对应测试
- Bug 修复必须有回归测试

---

## 测试覆盖率目标

- **代码覆盖率**: ≥ 80%
- **关键路径覆盖率**: 100%
- **边界情况覆盖率**: 100%

### 生成覆盖率报告

```bash
pip install pytest-cov

pytest tests/ --cov=caddy-validation-optimizer.sh --cov=test-caddy-validation.sh --cov-report=html
```
