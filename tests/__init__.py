"""
测试包初始化
"""
import os
import sys

# 添加项目根目录到 Python 路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Pytest 配置
def pytest_addoption(parser):
    """添加命令行选项"""
    parser.addoption(
        "--slow", action="store_true", dest="slow", default=False,
        help="运行慢速测试"
    )
    parser.addoption(
        "--verbose-logs", action="store_true", dest="verbose_logs", default=False,
        help="显示详细日志"
    )

def pytest_configure(config):
    """配置测试环境"""
    os.environ['V2RAY_ENV'] = 'testing'
    os.environ['LOG_FILE'] = '/tmp/v2ray-pytest.log'
