#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking shell syntax for retained scripts"

files=(install.sh tests/run.sh tests/shellcheck.sh)
for test_file in "$REPO_ROOT"/tests/testcase-*.sh "$REPO_ROOT"/tests/lib/*.sh; do
    [[ -f "$test_file" ]] || continue
    files+=("${test_file#"$REPO_ROOT/"}")
done

for file in "${files[@]}"; do
    bash -n "$REPO_ROOT/$file"
    pass "bash -n $file"
done
