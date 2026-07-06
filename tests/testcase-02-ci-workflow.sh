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
assert_contains ".github/workflows/ci.yml" 'bash tests/shellcheck\.sh' "CI invokes ShellCheck helper"
assert_not_contains ".github/workflows/ci.yml" 'skipped|too large for CI ShellCheck' "CI does not skip ShellCheck"
assert_contains ".github/workflows/ci.yml" 'bash -n' "CI runs bash syntax validation"
assert_contains "tests/shellcheck.sh" 'run_shellcheck install\.sh' "ShellCheck helper checks installer"
assert_contains "tests/shellcheck.sh" 'tests/\*\.sh' "ShellCheck helper checks test harness"
