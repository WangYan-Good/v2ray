#!/bin/bash
cd /home/node/.openclaw/v2ray

# Check functions before running main
bash -c '
source src/log.sh 2>/dev/null
source src/utils/error_handler.sh 2>/dev/null
init_error_handler 2>/dev/null

# Source the test file without running main
head -n 337 tests/test_error_handler.sh | bash 2>/dev/null

# Now check test functions
echo "Functions after sourcing:"
for f in $(declare -F | grep "^declare -f test_" | sed "s/declare -f //"); do
    echo "  - $f"
done
' 2>&1 | tail -20
