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

core_extra_excludes=(
    SC2010 # legacy ls/grep patterns in core.sh
    SC2053 # legacy unquoted [[ rhs ]] patterns in core.sh
    SC2089 # jq JSON string assembly in core.sh
    SC2090 # jq JSON string assembly in core.sh
    SC2115 # legacy guarded rm paths in core.sh
    SC2124 # legacy array-to-string assignments in core.sh
    SC2128 # legacy array expansion style in core.sh
    SC2206 # legacy unquoted array construction in core.sh
    SC2209 # literal string assignments that look like commands
    SC2221 # legacy case ordering in core.sh
    SC2222 # legacy case ordering in core.sh
    SC2254 # legacy case pattern expansion in core.sh
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

run_core_shellcheck() {
    local core_file="$ROOT_DIR/src/core.sh"
    local tmpdir
    local excludes
    local chunk
    local status=0

    tmpdir=$(mktemp -d)

    excludes=$(join_by_comma "${common_excludes[@]}" "${core_extra_excludes[@]}")

    echo "=== Checking src/core.sh (function chunks) ==="
    bash -n "$core_file"

    awk -v outdir="$tmpdir" '
    function open_file(name) {
        if (file != "") close(file)
        file = outdir "/" name
        print "#!/bin/bash" > file
    }
    BEGIN {
        idx = 0
        open_file(sprintf("core-%02d-preamble.sh", idx))
    }
    /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/ {
        idx++
        name = $0
        sub(/^[[:space:]]*/, "", name)
        sub(/\(\).*/, "", name)
        open_file(sprintf("core-%02d-%s.sh", idx, name))
    }
    { print >> file }
    END {
        if (file != "") close(file)
    }
    ' "$core_file"

    for chunk in "$tmpdir"/*.sh; do
        echo "Checking src/core.sh chunk: $(basename "$chunk")"
        if ! shellcheck --shell=bash --severity=warning --exclude="$excludes" "$chunk"; then
            status=1
        fi
    done

    rm -rf "$tmpdir"
    return "$status"
}

main() {
    local excludes
    local file

    excludes=$(join_by_comma "${common_excludes[@]}")

    echo "=== Checking install.sh ==="
    run_shellcheck install.sh "$excludes"

    echo "=== Checking xray.sh ==="
    run_shellcheck xray.sh "$excludes"

    echo "=== Checking src/*.sh ==="
    for file in "$ROOT_DIR"/src/*.sh; do
        file=${file#"$ROOT_DIR/"}
        if [[ $file == "src/core.sh" ]]; then
            run_core_shellcheck
        else
            run_shellcheck "$file" "$excludes"
        fi
    done

    echo "All ShellCheck checks passed"
}

main "$@"
