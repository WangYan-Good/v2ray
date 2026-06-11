#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking release packaging contract"

assert_file ".github/workflows/release.yml"
assert_contains ".github/workflows/release.yml" 'zip -r code\.zip install\.sh xray\.sh src/' "release packages install.sh, xray.sh, and src/"
assert_contains ".github/workflows/release.yml" 'zipinfo code\.zip.*install\.sh|grep -q "install\.sh"' "release verifies install.sh in code.zip"
assert_contains ".github/workflows/release.yml" 'zipinfo code\.zip.*xray\.sh|grep -q "xray\.sh"' "release verifies xray.sh in code.zip"
assert_contains ".github/workflows/release.yml" 'code\.zip' "release uploads code.zip"
assert_contains ".github/workflows/release.yml" 'install\.sh' "release uploads install.sh"
