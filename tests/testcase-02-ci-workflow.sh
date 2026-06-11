#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/lib/assert.sh"

note "checking CI workflow contract"

assert_file ".github/workflows/ci.yml"
assert_contains ".github/workflows/ci.yml" '^  pull_request:' "CI runs for pull requests"
assert_contains ".github/workflows/ci.yml" 'branches: \[develop, main, master\]' "CI targets develop/main/master"
assert_contains ".github/workflows/ci.yml" '^  workflow_dispatch:' "CI can be run manually"
assert_contains ".github/workflows/ci.yml" '^  automated-tests:' "CI has automated testcase job"
assert_contains ".github/workflows/ci.yml" 'bash tests/run\.sh' "CI invokes tests/run.sh"
assert_contains ".github/workflows/ci.yml" 'shellcheck --severity=warning' "CI runs ShellCheck"
assert_contains ".github/workflows/ci.yml" 'bash -n' "CI runs bash syntax validation"
