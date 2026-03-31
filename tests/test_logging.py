"""
日志记录测试

测试目标：验证日志记录功能的正确性
测试用例数量：5
"""
import os
import tempfile
import pytest
import subprocess


class TestLogging:
    """日志记录测试类"""
    
    @pytest.fixture
    def script_path(self):
        """获取脚本路径"""
        return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                          'scripts/caddy-validation-optimizer.sh')
    
    def test_log_message_info(self, script_path, tmp_path):
        """测试 6.1: INFO 级别日志"""
        log_file = str(tmp_path / "test.log")
        env = os.environ.copy()
        env['LOG_FILE'] = log_file
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && log_message "INFO" "test info message"'],
            capture_output=True,
            text=True,
            env=env
        )
        
        assert os.path.exists(log_file), "日志文件应被创建"
        with open(log_file, 'r') as f:
            content = f.read()
        assert 'INFO' in content and 'test info message' in content, "INFO 日志应包含级别和消息"
    
    def test_log_message_warn(self, script_path, tmp_path):
        """测试 6.2: WARN 级别日志"""
        log_file = str(tmp_path / "test.log")
        env = os.environ.copy()
        env['LOG_FILE'] = log_file
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && log_message "WARN" "test warn message"'],
            capture_output=True,
            text=True,
            env=env
        )
        
        assert os.path.exists(log_file), "日志文件应被创建"
        with open(log_file, 'r') as f:
            content = f.read()
        assert 'WARN' in content and 'test warn message' in content, "WARN 日志应包含级别和消息"
    
    def test_log_message_error(self, script_path, tmp_path):
        """测试 6.3: ERROR 级别日志"""
        log_file = str(tmp_path / "test.log")
        env = os.environ.copy()
        env['LOG_FILE'] = log_file
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && log_message "ERROR" "test error message"'],
            capture_output=True,
            text=True,
            env=env
        )
        
        assert os.path.exists(log_file), "日志文件应被创建"
        with open(log_file, 'r') as f:
            content = f.read()
        assert 'ERROR' in content and 'test error message' in content, "ERROR 日志应包含级别和消息"
    
    def test_log_timestamp(self, script_path, tmp_path):
        """测试 6.4: 日志时间戳"""
        log_file = str(tmp_path / "test.log")
        env = os.environ.copy()
        env['LOG_FILE'] = log_file
        
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && log_message "INFO" "timestamp test"'],
            capture_output=True,
            text=True,
            env=env
        )
        
        with open(log_file, 'r') as f:
            content = f.read()
        # 检查是否有时间戳格式 YYYY-MM-DD HH:MM:SS
        import re
        timestamp_pattern = r'\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]'
        assert re.search(timestamp_pattern, content), "日志应包含时间戳"
    
    def test_log_stderr_output(self, script_path):
        """测试 6.5: 日志输出到 stderr"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && log_message "ERROR" "stderr test"'],
            capture_output=True,
            text=True
        )
        # ERROR 级别应输出到 stderr
        assert 'ERROR' in result.stderr or 'stderr test' in result.stderr, "ERROR 日志应输出到 stderr"
