#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR="$ROOT_DIR/tests"
status=0
found=0

for test_file in "$TEST_DIR"/testcase-*.sh; do
    [[ -e "$test_file" ]] || continue
    found=1
    printf '\n==> %s\n' "$(basename "$test_file")"
    if bash "$test_file"; then
        printf 'PASS %s\n' "$(basename "$test_file")"
    else
        status=1
        printf 'FAIL %s\n' "$(basename "$test_file")" >&2
    fi
done

[[ $found -eq 1 ]] || {
    printf 'No testcase-*.sh files found in %s\n' "$TEST_DIR" >&2
    exit 1
}

exit "$status"
