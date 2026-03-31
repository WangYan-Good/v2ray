"""
边界情况测试

测试目标：验证边界条件和异常输入的处理
测试用例数量：5
"""
import os
import pytest
import subprocess


class TestEdgeCases:
    """边界情况测试类"""
    
    @pytest.fixture
    def script_path(self):
        """获取脚本路径"""
        return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                          'scripts/caddy-validation-optimizer.sh')
    
    def test_empty_error_log(self, script_path):
        """测试 5.1: 空错误日志"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error ""'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "0", "空错误日志应返回诊断码 0"
    
    def test_none_error_log(self, script_path):
        """测试 5.2: None 错误日志"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error ""'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "0", "None 错误日志应返回诊断码 0"
    
    def test_whitespace_only_log(self, script_path):
        """测试 5.3: 仅空白日志"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error "   "'],
            capture_output=True,
            text=True
        )
        # 应返回 0（其他问题）
        assert result.stdout.strip() == "0", "仅空白日志应返回诊断码 0"
    
    def test_very_long_error_log(self, script_path):
        """测试 5.4: 非常长的错误日志"""
        long_error = "error " * 1000
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error "{long_error}"'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() in ['0', '1', '2', '3', '4'], "长错误日志应返回有效诊断码"
    
    def test_special_characters_in_log(self, script_path):
        """测试 5.5: 错误日志中的特殊字符"""
        special_log = "error: file not found: /home/user/test'file\\\".conf"
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && analyze_validation_error "{special_log}"'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() in ['0', '1', '2', '3', '4'], "特殊字符日志应返回有效诊断码"
