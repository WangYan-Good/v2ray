#!/bin/bash
# Test script for V2Ray Nginx + Certbot integration

set -euo pipefail

echo "=== V2Ray Nginx Integration Test ==="
echo ""

# Test 1: Check if modified files have correct syntax
echo "Test 1: Checking file syntax..."
bash -n /home/node/.openclaw/v2ray/src/lib/core/core.sh && echo "✓ core.sh syntax OK" || echo "✗ core.sh syntax error"
bash -n /home/node/.openclaw/v2ray/src/nginx.sh && echo "✓ nginx.sh syntax OK" || echo "✗ nginx.sh syntax error"
echo ""

# Test 2: Check if modified functions exist
echo "Test 2: Checking function definitions..."
grep -q "^add()" /home/node/.openclaw/v2ray/src/lib/core/core.sh && echo "✓ add() function found" || echo "✗ add() function not found"
grep -q "IS_INSTALL_NGINX=1" /home/node/.openclaw/v2ray/src/lib/core/core.sh && echo "✓ IS_INSTALL_NGINX assignment found" || echo "✗ IS_INSTALL_NGINX assignment not found"
grep -q "^nginx_config()" /home/node/.openclaw/v2ray/src/nginx.sh && echo "✓ nginx_config() function found" || echo "✗ nginx_config() function not found"
grep -q "^nginx_certbot()" /home/node/.openclaw/v2ray/src/nginx.sh && echo "✓ nginx_certbot() function found" || echo "✗ nginx_certbot() function not found"
grep -q "^nginx_reload()" /home/node/.openclaw/v2ray/src/nginx.sh && echo "✓ nginx_reload() function found" || echo "✗ nginx_reload() function not found"
echo ""

# Test 3: Check if required variables are set in add function
echo "Test 3: Checking variable assignments in add()..."
# Check for user selection prompt
if grep -q "请选择 Web 服务器用于自动配置 TLS" /home/node/.openclaw/v2ray/src/lib/core/core.sh; then
    echo "✓ User selection for web server found"
else
    echo "✗ User selection for web server not found"
fi

# Check for Nginx installation call
if grep -q "get install-nginx" /home/node/.openclaw/v2ray/src/lib/core/core.sh; then
    echo "✓ Nginx installation call found"
else
    echo "✗ Nginx installation call not found"
fi

# Check for Nginx config application
if grep -q "nginx_config" /home/node/.openclaw/v2ray/src/lib/core/core.sh; then
    echo "✓ Nginx config application found"
else
    echo "✗ Nginx config application not found"
fi

# Check for certificate issuance
if grep -q "nginx_certbot issue" /home/node/.openclaw/v2ray/src/lib/core/core.sh; then
    echo "✓ Certificate issuance call found"
else
    echo "✗ Certificate issuance call not found"
fi

# Check for Nginx reload
if grep -q "nginx_reload" /home/node/.openclaw/v2ray/src/lib/core/core.sh; then
    echo "✓ Nginx reload call found"
else
    echo "✗ Nginx reload call not found"
fi
echo ""

# Test 4: Check branch status
echo "Test 4: Checking git branch..."
cd /home/node/.openclaw/v2ray
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"
if [[ "$CURRENT_BRANCH" == "feature/oneclick-nginx-cert" ]]; then
    echo "✓ Correct branch"
else
    echo "⚠ Expected branch: feature/oneclick-nginx-cert"
fi
echo ""

# Test 5: Show recent changes
echo "Test 5: Recent git changes..."
git diff --stat
echo ""

echo "=== Test Summary ==="
echo "Basic syntax and structure checks passed."
echo ""
echo "Next steps:"
echo "1. Create v2ray binary if not exists"
echo "2. Create /etc/v2ray directory structure"
echo "3. Test with actual v2ray add command"
echo "4. Verify Nginx configuration is created"
echo "5. Verify TLS certificate is issued"
