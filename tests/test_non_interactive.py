"""
非交互式环境测试

测试目标：验证非交互式/自动化环境下的行为
测试用例数量：5
"""
import os
import pytest
import subprocess


class TestNonInteractive:
    """非交互式环境测试类"""
    
    @pytest.fixture
    def script_path(self):
        """获取脚本路径"""
        return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                          'caddy-validation-optimizer.sh')
    
    def test_noninteractive_mode_env(self, script_path):
        """测试 9.1: 非交互式环境变量"""
        # 设置非交互式环境变量
        env = os.environ.copy()
        env['CI'] = 'true'
        env['NONINTERACTIVE'] = 'true'
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && IDENTIFY_ENVIRONMENT'],
            capture_output=True,
            text=True,
            env=env
        )
        # 应仍返回环境标识
        assert result.stdout.strip() in ['production', 'development', 'testing'], "应返回有效环境标识"
    
    def test_noninteractive_parse_args(self, script_path):
        """测试 9.2: 非交互式参数解析"""
        env = os.environ.copy()
        env['CI'] = 'true'
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--skip-dns-check" "--force-deploy"'],
            capture_output=True,
            text=True,
            env=env
        )
        assert '--skip-dns-check' in result.stdout, "应解析 --skip-dns-check"
        assert '--force-deploy' in result.stdout, "应解析 --force-deploy"
    
    def test_noninteractive_logging(self, script_path, tmp_path):
        """测试 9.3: 非交互式日志记录"""
        log_file = str(tmp_path / "ci.log")
        env = os.environ.copy()
        env['CI'] = 'true'
        env['LOG_FILE'] = log_file
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && log_message "INFO" "CI test"'],
            capture_output=True,
            text=True,
            env=env
        )
        
        assert os.path.exists(log_file), "日志文件应被创建"
        with open(log_file, 'r') as f:
            content = f.read()
        assert 'CI test' in content, "日志应包含消息"
    
    def test_noninteractive_automation(self, script_path):
        """测试 9.4: 非交互式自动化调用"""
        env = os.environ.copy()
        env['CI'] = 'true'
        env['NONINTERACTIVE'] = 'true'
        
        # 模拟自动化流程
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error ""'],
            capture_output=True,
            text=True,
            env=env
        )
        assert result.stdout.strip() == "0", "应返回诊断码 0"
    
    def test_noninteractive_batch_mode(self, script_path):
        """测试 9.5: 批处理模式"""
        env = os.environ.copy()
        env['BATCH_MODE'] = 'true'
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--no-auto-fix"'],
            capture_output=True,
            text=True,
            env=env
        )
        assert '--no-auto-fix' in result.stdout, "应解析 --no-auto-fix"
