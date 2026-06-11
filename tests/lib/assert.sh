#!/usr/bin/env bash

set -euo pipefail

TEST_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=${REPO_ROOT:-$(cd "$TEST_LIB_DIR/../.." && pwd)}

note() {
    printf '# %s\n' "$*"
}

pass() {
    printf 'ok - %s\n' "$*"
}

fail() {
    printf 'not ok - %s\n' "$*" >&2
    exit 1
}

assert_file() {
    local file="$1"
    [[ -f "$REPO_ROOT/$file" ]] || fail "missing file: $file"
    pass "file exists: $file"
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local message="$3"

    grep -Eq -- "$pattern" "$REPO_ROOT/$file" || fail "$message"
    pass "$message"
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local message="$3"

    if grep -Eq -- "$pattern" "$REPO_ROOT/$file"; then
        fail "$message"
    fi
    pass "$message"
}
