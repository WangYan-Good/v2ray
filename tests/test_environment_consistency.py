"""
环境一致性测试

测试目标：确保不同环境下的配置一致性
测试用例数量：6
"""
import os
import pytest
import subprocess


class TestEnvironmentConsistency:
    """环境一致性测试类"""
    
    @pytest.fixture
    def script_path(self):
        """获取脚本路径"""
        return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                          'scripts/caddy-validation-optimizer.sh')
    
    def test_production_env_identification(self, script_path):
        """测试 1.1: 生产环境识别"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && V2RAY_ENV=production IDENTIFY_ENVIRONMENT'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "production", "生产环境识别失败"
    
    def test_development_env_identification(self, script_path):
        """测试 1.2: 开发环境识别"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && V2RAY_ENV=development IDENTIFY_ENVIRONMENT'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "development", "开发环境识别失败"
    
    def test_testing_env_identification(self, script_path):
        """测试 1.3: 测试环境识别"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && V2RAY_ENV=testing IDENTIFY_ENVIRONMENT'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == "testing", "测试环境识别失败"
    
    def test_default_env_identification(self, script_path):
        """测试 1.4: 默认环境识别（无设置）"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && IDENTIFY_ENVIRONMENT'],
            capture_output=True,
            text=True,
            env={k: v for k, v in os.environ.items() if k != 'V2RAY_ENV'}
        )
        assert result.stdout.strip() == "production", "默认环境应为 production"
    
    def test_diagnostic_codes_defined(self, script_path):
        """测试 1.5: 诊断码常量已定义"""
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && echo $DIAG_CODE_OTHER $DIAG_CODE_DNS $DIAG_CODE_CLOUDFLARE $DIAG_CODE_PLACEHOLDER $DIAG_CODE_VERSION'],
            capture_output=True,
            text=True
        )
        codes = result.stdout.strip().split()
        assert len(codes) == 5, "诊断码常量应有 5 个"
        assert codes == ['0', '1', '2', '3', '4'], "诊断码值应为 0-4"
    
    def test_log_file_configuration(self, script_path):
        """测试 1.6: 日志文件配置"""
        # 测试使用 LOG_FILE 环境变量
        os.environ['LOG_FILE'] = '/tmp/test-log-file.log'
        result = subprocess.run(
            ['bash', '-c', f'source "{script_path}" && echo $LOG_FILE'],
            capture_output=True,
            text=True
        )
        assert '/tmp/test-log-file.log' in result.stdout, "日志文件路径配置失败"
