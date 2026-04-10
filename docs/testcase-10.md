# Test Case 10 — Shell Quoting and ShellCheck Validation

## Objective
Validate and fix shell quoting issues in `install.sh` to ensure safe variable expansion, avoid word-splitting, and reduce ShellCheck warnings in the T10 branch.

## Scope
- `install.sh`
- `install_pkg` dependency install flow
- dynamic sourcing in `load()`
- temporary path exports
- file path handling and `read` prompts

## Test Environment
- Local development workspace: `/mnt/main/CodeSpace/Project/xray`
- Remote test server repository: `/mnt/code/xray`
- Validation executed with `shellcheck install.sh`

## Actions Taken
1. Quoted all dynamic path and command variables in `install.sh`.
2. Updated `install_pkg()` to handle package names safely with quoted arguments.
3. Added explicit initialization for temporary file variables used via dynamic exports.
4. Added `# shellcheck disable=SC1090` for dynamic script sourcing in `load()`.
5. Replaced unsafe `read` usage with `read -r` in user prompt blocks.
6. Replaced exit-status checks using `$?` in dangerous constructs with explicit `if` statements.
7. Tested using ShellCheck both locally and on remote server.

## Validation Results
- Local ShellCheck: no SC2086 or SC2154 quoting errors remain in `install.sh`.
- Remote ShellCheck on the server repo also shows only informational/unused-variable warnings (`SC2034`, `SC2317`) that are not related to quoting safety.

## Notes
- A backup of the remote file was saved before syncing updates.
- Remaining ShellCheck warnings are primarily due to unused internal constants and helper functions, not unquoted variable expansions.
