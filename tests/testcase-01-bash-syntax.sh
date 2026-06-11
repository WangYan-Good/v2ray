#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking bash syntax"

files=(
    install.sh
    xray.sh
)

for src_file in "$REPO_ROOT"/src/*.sh; do
    files+=("src/$(basename "$src_file")")
done

for file in "${files[@]}"; do
    bash -n "$REPO_ROOT/$file"
    pass "bash -n $file"
done
