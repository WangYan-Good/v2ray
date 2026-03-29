"""Pytest 配置文件"""
import os
import sys
import subprocess
import pytest

# 添加项目根目录到 Python 路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def pytest_addoption(parser):
    """添加命令行选项"""
    parser.addoption(
        "--slow", action="store_true", default=False,
        help="运行慢速测试"
    )
    parser.addoption(
        "--verbose-logs", action="store_true", default=False,
        help="显示详细日志"
    )

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

@pytest.fixture
def placeholder_config(tmp_path):
    """创建包含占位符域名的 Caddy 配置文件"""
    config = tmp_path / "Caddyfile"
    config.write_text(":443 {\n    reverse_proxy yourdomain.com:8080\n}")
    return str(config)

@pytest.fixture
def run_bash_function():
    """运行 bash 函数的辅助函数"""
    def _run_bash_function(script_path, function_name, *args):
        args_str = ' '.join(f'"{arg}"' for arg in args)
        cmd = f'source "{script_path}" && {function_name} {args_str}'
        result = subprocess.run(
            ['bash', '-c', cmd],
            capture_output=True,
            text=True,
            env={**os.environ, 'V2RAY_ENV': 'testing'}
        )
        return result
    return _run_bash_function

@pytest.fixture
def run_bash_function_with_env():
    """运行 bash 函数并设置环境变量的辅助函数"""
    def _run_bash_function(script_path, function_name, env_vars, *args):
        args_str = ' '.join(f'"{arg}"' for arg in args)
        env_str = ' '.join(f'{k}="{v}"' for k, v in env_vars.items())
        cmd = f'source "{script_path}" && {env_str} {function_name} {args_str}'
        result = subprocess.run(
            ['bash', '-c', cmd],
            capture_output=True,
            text=True
        )
        return result
    return _run_bash_function
