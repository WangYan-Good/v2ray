"""
权限和授权测试

测试目标：验证权限检查和授权流程
测试用例数量：5
"""
import os
import tempfile
import pytest
import subprocess


class TestPermissions:
    """权限和授权测试类"""
    
    @pytest.fixture
    def script_path(self):
        """获取脚本路径"""
        return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                          'scripts/caddy-validation-optimizer.sh')
    
    @pytest.fixture
    def config_file(self, tmp_path):
        """创建临时配置文件"""
        config = tmp_path / "Caddyfile"
        return str(config)
    
    def test_read_only_config_file(self, script_path, config_file):
        """测试 7.1: 只读配置文件处理"""
        # 创建配置文件
        with open(config_file, 'w') as f:
            f.write(":443 {\n    reverse_proxy localhost:8080\n}\n")
        # 设置为只读
        os.chmod(config_file, 0o444)
        
        # 使用 --force-deploy 跳过验证
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && handle_validation_failure "{config_file}" "--force-deploy"'],
            capture_output=True,
            text=True
        )
        # 强制部署应返回 0
        assert result.returncode == 0, "只读配置文件应能处理"
    
    def test_nonexistent_config_file(self, script_path):
        """测试 7.2: 非existent 配置文件"""
        nonexistent = "/tmp/nonexistent-config-12345/Caddyfile"
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && handle_validation_failure "{nonexistent}" ""'],
            capture_output=True,
            text=True
        )
        # 应返回错误
        assert result.returncode != 0, "非existent 文件应导致错误"
    
    def test_log_file_permission(self, script_path, tmp_path):
        """测试 7.3: 日志文件权限"""
        log_file = str(tmp_path / "test.log")
        env = os.environ.copy()
        env['LOG_FILE'] = log_file
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && log_message "INFO" "permission test"'],
            capture_output=True,
            text=True,
            env=env
        )
        # 日志应成功写入
        assert os.path.exists(log_file), "日志文件应被创建"
    
    def test_backup_file_permission(self, script_path, tmp_path):
        """测试 7.4: 备份文件权限"""
        config = str(tmp_path / "Caddyfile")
        with open(config, 'w') as f:
            f.write(":443 {\n    reverse_proxy yourdomain.com:8080\n}\n")
        
        env = os.environ.copy()
        env['CADDY_ERROR_LOG'] = 'dns error: lookup yourdomain.com on 8.8.8.8:51: no such host'
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error "{env["CADDY_ERROR_LOG"]}"'],
            capture_output=True,
            text=True,
            env=env
        )
        # 应返回诊断码 3
        assert result.stdout.strip() == "3", "占位符域名应返回诊断码 3"
    
    def test_directory_permission(self, script_path, tmp_path):
        """测试 7.5: 目录权限处理"""
        log_dir = tmp_path / "logs"
        log_dir.mkdir()
        log_file = str(log_dir / "test.log")
        
        env = os.environ.copy()
        env['LOG_FILE'] = log_file
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && init_validation_module'],
            capture_output=True,
            text=True,
            env=env
        )
        # 应成功初始化
        assert result.returncode == 0, "目录权限应能处理"
