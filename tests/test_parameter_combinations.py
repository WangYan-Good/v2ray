"""
参数组合测试

测试目标：验证不同参数组合的行为
测试用例数量：6
"""
import os
import pytest
import subprocess


class TestParameterCombinations:
    """参数组合测试类"""
    
    @pytest.fixture
    def script_path(self):
        """获取脚本路径"""
        return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                          'caddy-validation-optimizer.sh')
    
    def test_skip_dns_with_force_deploy(self, script_path):
        """测试 8.1: --skip-dns-check + --force-deploy 组合"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--skip-dns-check" "--force-deploy"'],
            capture_output=True,
            text=True
        )
        assert '--skip-dns-check' in result.stdout, "应包含 --skip-dns-check"
        assert '--force-deploy' in result.stdout, "应包含 --force-deploy"
    
    def test_skip_tls_with_force_deploy(self, script_path):
        """测试 8.2: --skip-tls-check + --force-deploy 组合"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--skip-tls-check" "--force-deploy"'],
            capture_output=True,
            text=True
        )
        assert '--skip-tls-check' in result.stdout, "应包含 --skip-tls-check"
        assert '--force-deploy' in result.stdout, "应包含 --force-deploy"
    
    def test_all_skip_flags_with_no_auto_fix(self, script_path):
        """测试 8.3: 所有跳过标志 + --no-auto-fix 组合"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--skip-dns-check" "--skip-tls-check" "--no-auto-fix"'],
            capture_output=True,
            text=True
        )
        assert '--skip-dns-check' in result.stdout, "应包含 --skip-dns-check"
        assert '--skip-tls-check' in result.stdout, "应包含 --skip-tls-check"
        assert '--no-auto-fix' in result.stdout, "应包含 --no-auto-fix"
    
    def test_dev_mode_overrides(self, script_path):
        """测试 8.4: --dev-mode 自动覆盖标志"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--dev-mode"'],
            capture_output=True,
            text=True
        )
        # dev-mode 应自动添加 skip-dns-check 和 skip-tls-check
        assert '--skip-dns-check' in result.stdout, "--dev-mode 应自动添加 --skip-dns-check"
        assert '--skip-tls-check' in result.stdout, "--dev-mode 应自动添加 --skip-tls-check"
    
    def test_dev_mode_with_explicit_skip(self, script_path):
        """测试 8.5: --dev-mode + 显式跳过标志"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--dev-mode" "--skip-dns-check"'],
            capture_output=True,
            text=True
        )
        # dev-mode 应已添加 skip-dns-check
        assert '--skip-dns-check' in result.stdout, "应包含 --skip-dns-check"
        assert '--skip-tls-check' in result.stdout, "应包含 --skip-tls-check"
    
    def test_all_flags_together(self, script_path):
        """测试 8.6: 所有标志组合"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--skip-dns-check" "--skip-tls-check" "--force-deploy" "--no-auto-fix" "--dev-mode"'],
            capture_output=True,
            text=True
        )
        # dev-mode 应自动添加 skip-dns-check 和 skip-tls-check
        assert '--skip-dns-check' in result.stdout, "应包含 --skip-dns-check"
        assert '--skip-tls-check' in result.stdout, "应包含 --skip-tls-check"
        assert '--force-deploy' in result.stdout, "应包含 --force-deploy"
        assert '--no-auto-fix' in result.stdout, "应包含 --no-auto-fix"
