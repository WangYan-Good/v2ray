"""
显式覆盖标志测试

测试目标：验证所有覆盖标志的正确实现
测试用例数量：6
"""
import os
import pytest
import subprocess


class TestOverrideFlags:
    """显式覆盖标志测试类"""
    
    @pytest.fixture
    def script_path(self):
        """获取脚本路径"""
        return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                          'scripts/caddy-validation-optimizer.sh')
    
    def test_skip_dns_check_flag(self, script_path):
        """测试 4.1: --skip-dns-check 标志"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--skip-dns-check"'],
            capture_output=True,
            text=True
        )
        assert '--skip-dns-check' in result.stdout, "--skip-dns-check 应包含在输出中"
    
    def test_skip_tls_check_flag(self, script_path):
        """测试 4.2: --skip-tls-check 标志"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--skip-tls-check"'],
            capture_output=True,
            text=True
        )
        assert '--skip-tls-check' in result.stdout, "--skip-tls-check 应包含在输出中"
    
    def test_force_deploy_flag(self, script_path):
        """测试 4.3: --force-deploy 标志"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--force-deploy"'],
            capture_output=True,
            text=True
        )
        assert '--force-deploy' in result.stdout, "--force-deploy 应包含在输出中"
    
    def test_dev_mode_flag(self, script_path):
        """测试 4.4: --dev-mode 标志"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--dev-mode"'],
            capture_output=True,
            text=True
        )
        # dev-mode 应自动添加 skip-dns-check 和 skip-tls-check
        assert '--skip-dns-check' in result.stdout, "--dev-mode 应自动添加 --skip-dns-check"
        assert '--skip-tls-check' in result.stdout, "--dev-mode 应自动添加 --skip-tls-check"
    
    def test_no_auto_fix_flag(self, script_path):
        """测试 4.5: --no-auto-fix 标志"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--no-auto-fix"'],
            capture_output=True,
            text=True
        )
        assert '--no-auto-fix' in result.stdout, "--no-auto-fix 应包含在输出中"
    
    def test_multiple_flags_combination(self, script_path):
        """测试 4.6: 多个标志组合"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--skip-dns-check" "--skip-tls-check" "--force-deploy" "--no-auto-fix"'],
            capture_output=True,
            text=True
        )
        assert '--skip-dns-check' in result.stdout, "应包含 --skip-dns-check"
        assert '--skip-tls-check' in result.stdout, "应包含 --skip-tls-check"
        assert '--force-deploy' in result.stdout, "应包含 --force-deploy"
        assert '--no-auto-fix' in result.stdout, "应包含 --no-auto-fix"
