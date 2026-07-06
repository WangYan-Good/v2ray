#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

common_excludes=(
    SC1078 # here-doc warnings in generated configs
    SC1090 # dynamic source/load() pattern
    SC2034 # dynamically sourced variables
    SC2046 # project heredoc/cat style
    SC2062 # project grep pattern style
    SC2068 # project $@ style
    SC2140 # project echo/cat style
    SC2145 # project array/string mixing style
    SC2154 # dynamically sourced variables
    SC2155 # project local var=$(cmd) style
    SC2207 # project array assignment style
    SC2317 # functions called indirectly
)

join_by_comma() {
    local IFS=,
    echo "$*"
}

run_shellcheck() {
    local file="$1"
    local excludes="$2"

    echo "Checking $file..."
    shellcheck --shell=bash --severity=warning --exclude="$excludes" "$ROOT_DIR/$file"
}

main() {
    local excludes
    local file

    excludes=$(join_by_comma "${common_excludes[@]}")

    echo "=== Checking install.sh ==="
    run_shellcheck install.sh "$excludes"

    echo "=== Checking tests/*.sh ==="
    for file in "$ROOT_DIR"/tests/*.sh "$ROOT_DIR"/tests/lib/*.sh; do
        [[ -f "$file" ]] || continue
        file=${file#"$ROOT_DIR/"}
        run_shellcheck "$file" "$excludes"
    done

    echo "All ShellCheck checks passed"
}

main "$@"
