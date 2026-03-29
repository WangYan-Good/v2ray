tests_dir=$(dirname "$0")
lib_dir="$tests_dir/../lib"

# 确保 tests 目录存在
mkdir -p "$tests_dir"

# 创建 __init__.py
cat > "$tests_dir/__init__.py" << 'PYEOF'
"""测试包初始化"""
PYEOF

# 创建 conftest.py
cat > "$tests_dir/conftest.py" << 'PYEOF'
"""Pytest 配置文件"""
import os
import sys
import pytest

# 添加项目根目录到 Python 路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def pytest_configure(config):
    """配置测试环境"""
    os.environ['V2RAY_ENV'] = 'testing'
    os.environ['LOG_FILE'] = '/tmp/v2ray-pytest.log'

@pytest.fixture
def bash_script():
    """提供 bash 脚本路径"""
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(root_dir, 'caddy-validation-optimizer.sh')

@pytest.fixture
def test_script():
    """提供测试脚本路径"""
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(root_dir, 'test-caddy-validation.sh')

@pytest.fixture
def sample_config(tmp_path):
    """创建示例 Caddy 配置文件"""
    config = tmp_path / "Caddyfile"
    config.write_text(":443 {\n    reverse_proxy localhost:8080\n}")
    return str(config)
PYEOF

echo "测试框架目录结构已创建"
ls -la "$tests_dir"
PYEOF