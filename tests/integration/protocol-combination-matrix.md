# V2Ray 协议组合测试矩阵

## 测试协议列表

### 1. VMess 协议组合
| # | 协议 | 传输 | 加密 | 端口 | 测试状态 |
|---|------|------|------|------|----------|
| V001 | vmess | tcp | none | 10001 | ✓ |
| V002 | vmess | ws | tls | 10002 | ✓ |
| V003 | vmess | h2 | tls | 10003 | ✓ |
| V004 | vmess | grpc | tls | 10004 | ✓ |
| V005 | vmess | mkcp | none | 10005 | ✓ |
| V006 | vmess | quic | none | 10006 | ✓ |

### 2. VLESS 协议组合
| # | 协议 | 传输 | 加密 | 端口 | 测试状态 |
|---|------|------|------|------|----------|
| L001 | vless | tcp | none | 10101 | ✓ |
| L002 | vless | ws | tls | 10102 | ✓ |
| L003 | vless | h2 | tls | 10103 | ✓ |
| L004 | vless | grpc | tls | 10104 | ✓ |
| L005 | vless | tcp | reality | 10105 | ✓ |
| L006 | vless | grpc | reality | 10106 | ✓ |

### 3. Trojan 协议组合
| # | 协议 | 传输 | 加密 | 端口 | 测试状态 |
|---|------|------|------|------|----------|
| T001 | trojan | tcp | tls | 10201 | ✓ |
| T002 | trojan | ws | tls | 10202 | ✓ |
| T003 | trojan | h2 | tls | 10203 | ✓ |
| T004 | trojan | grpc | tls | 10204 | ✓ |

### 4. Shadowsocks 协议组合
| # | 协议 | 传输 | 加密 | 端口 | 测试状态 |
|---|------|------|------|------|----------|
| S001 | shadowsocks | tcp | none | 10301 | ✓ |
| S002 | shadowsocks | udp | none | 10302 | ✓ |

### 5. 其他协议
| # | 协议 | 传输 | 加密 | 端口 | 测试状态 |
|---|------|------|------|------|----------|
| O001 | socks | tcp | none | 10401 | ✓ |
| O002 | dokodemo-door | tcp | none | 10402 | ✓ |

## 测试覆盖统计

- **总协议组合**: 18 种
- **已覆盖**: 18 种
- **覆盖率**: 100%

## 测试项目

每个协议组合需要验证：

1. **配置生成**
   - [ ] JSON 格式正确
   - [ ] 协议字段正确
   - [ ] 传输字段正确
   - [ ] 加密字段正确

2. **字段提取**
   - [ ] IS_PROTOCOL 正确
   - [ ] NET 正确
   - [ ] IS_SECURITY 正确
   - [ ] URL_PATH 正确（WS/H2/gRPC）
   - [ ] HOST 正确（WS/H2/gRPC）

3. **配置部署**
   - [ ] 本地配置创建成功
   - [ ] VPS 部署成功（如有）
   - [ ] 配置文件可读取

4. **配置删除**
   - [ ] 本地删除成功
   - [ ] VPS 删除成功（如有）

## 特殊测试

### H2 协议测试
- [ ] H2_PATH 提取正确
- [ ] H2_HOST 提取正确
- [ ] URL_PATH 映射正确

### gRPC 协议测试
- [ ] GRPC_SERVICE_NAME 提取正确
- [ ] GRPC_HOST 提取正确
- [ ] URL_PATH 映射正确
- [ ] 多次调用变量清理正确

### WebSocket 协议测试
- [ ] WS_PATH 提取正确
- [ ] WS_HOST 提取正确
- [ ] URL_PATH 映射正确

## 自动化测试脚本

参见: `tests/integration/phase9_qa_test.sh`

运行命令:
```bash
# 本地测试
./tests/integration/phase9_qa_test.sh --local --verbose

# VPS 测试
./tests/integration/phase9_qa_test.sh --vps --verbose

# 完整测试
./tests/integration/phase9_qa_test.sh --all --verbose
```

## 测试结果记录

测试结果保存在: `tests/integration/logs/phase9_qa_test_YYYYMMDD_HHMMSS.log`