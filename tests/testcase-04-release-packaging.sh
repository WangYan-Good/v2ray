#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking release packaging contract"

assert_file ".github/workflows/release.yml"
assert_not_contains ".github/workflows/release.yml" 'code\.zip|xray\.sh|src/' "release does not package Bash runtime"
assert_contains ".github/workflows/release.yml" 'install\.sh' "release uploads install.sh"
assert_contains ".github/workflows/release.yml" 'xray-linux-amd64\.tar\.gz' "release uploads amd64 Go asset"
assert_contains ".github/workflows/release.yml" 'xray-linux-arm64\.tar\.gz' "release uploads arm64 Go asset"
assert_contains ".github/workflows/release.yml" 'checksums\.txt' "release uploads checksums"
