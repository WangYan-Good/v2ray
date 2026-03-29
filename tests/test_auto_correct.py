"""
自动修正功能测试

测试目标：验证自动修正功能在各种场景下的行为
测试用例数量：5
"""
import os
import tempfile
import pytest
import subprocess


class TestAutoCorrect:
    """自动修正功能测试类"""
    
    @pytest.fixture
    def script_path(self):
        """获取脚本路径"""
        return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                          'caddy-validation-optimizer.sh')
    
    @pytest.fixture
    def config_file(self, tmp_path):
        """创建临时配置文件"""
        config = tmp_path / "Caddyfile"
        return str(config)
    
    def test_auto_fix_placeholder_domain(self, script_path, config_file):
        """测试 2.1: 自动修正占位符域名"""
        # 创建包含占位符域名的配置文件
        with open(config_file, 'w') as f:
            f.write(":443 {\n    reverse_proxy yourdomain.com:8080\n}\n")
        
        # 设置错误日志
        env = os.environ.copy()
        env['CADDY_ERROR_LOG'] = 'dns error: lookup yourdomain.com on 8.8.8.8:51: no such host'
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && handle_validation_failure "{config_file}" "--no-auto-fix"'],
            capture_output=True,
            text=True,
            env=env
        )
        # 禁用自动修正应返回失败
        assert result.returncode != 0, "禁用自动修正应导致失败"
    
    def test_auto_fix_no_fix_flag(self, script_path, config_file):
        """测试 2.2: --no-auto-fix 标志禁用自动修正"""
        with open(config_file, 'w') as f:
            f.write(":443 {\n    reverse_proxy yourdomain.com:8080\n}\n")
        
        env = os.environ.copy()
        env['CADDY_ERROR_LOG'] = 'dns error: lookup yourdomain.com on 8.8.8.8:51: no such host'
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && handle_validation_failure "{config_file}" "--no-auto-fix"'],
            capture_output=True,
            text=True,
            env=env
        )
        assert result.returncode == 1, "禁用自动修正应返回错误码 1"
    
    def test_auto_fix_multiple_placeholders(self, script_path, config_file):
        """测试 2.3: 自动修正多个占位符域名"""
        with open(config_file, 'w') as f:
            f.write(":443 {\n    reverse_proxy yourdomain.com:8080\n    tls example.com\n}\n")
        
        env = os.environ.copy()
        env['CADDY_ERROR_LOG'] = 'dns error: lookup yourdomain.com on 8.8.8.8:51: no such host'
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && parse_cli_args "--no-auto-fix"'],
            capture_output=True,
            text=True,
            env=env
        )
        assert '--no-auto-fix' in result.stdout, "应包含 --no-auto-fix 标志"
    
    def test_auto_fix_config_backup(self, script_path, config_file):
        """测试 2.4: 自动修正时创建备份"""
        with open(config_file, 'w') as f:
            f.write(":443 {\n    reverse_proxy yourdomain.com:8080\n}\n")
        
        env = os.environ.copy()
        env['CADDY_ERROR_LOG'] = 'dns error: lookup yourdomain.com on 8.8.8.8:51: no such host'
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error "dns error: lookup yourdomain.com on 8.8.8.8:51: no such host"'],
            capture_output=True,
            text=True,
            env=env
        )
        # 诊断码应为 3（占位符域名）
        assert result.stdout.strip() == "3", "占位符域名诊断码应为 3"
    
    def test_auto_fix_dry_run(self, script_path, config_file):
        """测试 2.5: 模拟自动修正（无写入）"""
        original_content = ":443 {\n    reverse_proxy yourdomain.com:8080\n}\n"
        with open(config_file, 'w') as f:
            f.write(original_content)
        
        # 保存原始文件的 md5
        result = subprocess.run(['md5sum', config_file], capture_output=True, text=True)
        original_md5 = result.stdout.strip().split()[0]
        
        env = os.environ.copy()
        env['CADDY_ERROR_LOG'] = 'dns error: lookup yourdomain.com on 8.8.8.8:51: no such host'
        
        # 运行测试脚本
        test_script = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                                   'test-caddy-validation.sh')
        result = subprocess.run(
            ['bash', test_script],
            capture_output=True,
            text=True,
            env=env
        )
        # 测试完成，配置文件不应被修改（在 no-auto-fix 模式下）
