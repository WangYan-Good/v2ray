#!/bin/bash
cd /home/node/.openclaw/v2ray

echo "=== Testing Fixed info() Function ==="
echo ""

# 创建测试配置
mkdir -p /tmp/v2ray-vps-test
cat > /tmp/v2ray-vps-test/test-trojan-grpc.json << 'EOF'
{
  "inbounds": [
    {
      "tag": "test",
      "port": 443,
      "protocol": "trojan",
      "listen": "0.0.0.0",
      "settings": {
        "clients": [
          {
            "password": "975a95b5-694d-45c6-8de4-eafa6607c247"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "security": "tls",
        "grpcSettings": {
          "serviceName": "grpc"
        },
        "tlsSettings": {
          "serverName": "proxy.yourdie.com"
        }
      }
    }
  ]
}
EOF

# 运行测试
bash -c 'export JQ="/tmp/jq" && export IS_CONF_DIR="/tmp/v2ray-vps-test" && source src/core.sh && get info test-trojan-grpc.json && echo "---" && echo "IS_PROTOCOL: $IS_PROTOCOL" && echo "PORT: $PORT" && echo "UUID: $UUID" && echo "NET: $NET" && echo "IS_SECURITY: $IS_SECURITY" && echo "GRPC_SERVICE_NAME: $GRPC_SERVICE_NAME" && echo "URL_PATH: $URL_PATH" && echo "TROJAN_PASSWORD: $TROJAN_PASSWORD"' 2>&1 || true

echo ""
echo "=== 验证结果 ==="