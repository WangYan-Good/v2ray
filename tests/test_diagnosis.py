"""
诊断功能测试

测试目标：验证诊断码的正确性和诊断逻辑
测试用例数量：6
"""
import os
import pytest
import subprocess


class TestDiagnosis:
    """诊断功能测试类"""
    
    @pytest.fixture
    def script_path(self):
        """获取脚本路径"""
        return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                          'caddy-validation-optimizer.sh')
    
    def test_diagnostic_code_other(self, script_path):
        """测试 3.1: 其他问题诊断码 (code=0)"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error "parse error: unexpected character"'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "0", "解析错误应返回诊断码 0"
    
    def test_diagnostic_code_dns(self, script_path):
        """测试 3.2: DNS 问题诊断码 (code=1)"""
        # 使用 resolver 而非 example.com 来避免占位符匹配
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error "resolver error: dialing: lookup dns.example.com on 8.8.8.8:51: no such host"'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "1", "DNS 错误应返回诊断码 1"
    
    def test_diagnostic_code_cloudflare(self, script_path):
        """测试 3.3: Cloudflare 问题诊断码 (code=2)"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error "cloudflare: API error: 10000: Invalid API token provided"'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "2", "Cloudflare API 错误应返回诊断码 2"
    
    def test_diagnostic_code_placeholder(self, script_path):
        """测试 3.4: 占位符域名诊断码 (code=3)"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error "dns error: lookup yourdomain.com on 8.8.8.8:51: no such host"'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "3", "占位符域名应返回诊断码 3"
    
    def test_diagnostic_code_version(self, script_path):
        """测试 3.5: Caddy 版本兼容性诊断码 (code=4)"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error "Error parsing Caddyfile: json: unknown field \\"admin_disabled\\""',],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "4", "版本兼容性错误应返回诊断码 4"
    
    def test_empty_log_diagnosis(self, script_path):
        """测试 3.6: 空日志诊断"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error ""'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "0", "空日志应返回诊断码 0"
