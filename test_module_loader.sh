#!/bin/bash
source "src/lib/common/error.sh"
source "src/lib/common/module_loader.sh"
source "src/lib/common/init.sh"
source "src/lib/common/log.sh"

echo "=== Test: parse_all_dependencies with missing second argument ==="
# Test without second argument - should not throw error
parse_all_dependencies "/tmp" 2>&1 || echo "Expected to return non-zero for non-existent dir"

echo ""
echo "=== Test: safe_load_module function exists ==="
if declare -f safe_load_module > /dev/null; then
    echo "safe_load_module function is defined"
else
    echo "ERROR: safe_load_module function is NOT defined"
fi

echo ""
echo "=== Test: find_module_path function exists ==="
if declare -f find_module_path > /dev/null; then
    echo "find_module_path function is defined"
else
    echo "ERROR: find_module_path function is NOT defined"
fi

echo ""
echo "=== Test: init_logging function exists ==="
if declare -f init_logging > /dev/null; then
    echo "init_logging function is defined"
else
    echo "ERROR: init_logging function is NOT defined"
fi

echo ""
echo "=== Test: Error codes exist ==="
echo "ERR_MODULE_NOT_FOUND=$ERR_MODULE_NOT_FOUND"
echo "ERR_MODULE_LOAD=$ERR_MODULE_LOAD"

echo ""
echo "=== All tests completed ==="
