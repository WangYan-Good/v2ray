# Error Handling Framework

A comprehensive error handling framework for V2Ray installation scripts.

## Overview

The error handler provides:
- Unified error codes
- Enhanced error reporting with call stack traces
- Retry mechanisms with exponential backoff
- Safe file operations (rm, mkdir, cp, mv)
- Cleanup function registration
- Service status checking and management
- Context management for subshells

## Quick Start

```bash
# Source the error handler
source src/utils/error_handler.sh

# Initialize the framework
init_error_handler

# Your script logic here...

# Cleanup on exit
execute_cleanup
```

## Error Handling

### Basic Error Exit

```bash
error_exit "Error message" $ERR_GENERAL false
```

### Recoverable Errors

```bash
error_exit "Warning message" $ERR_GENERAL true
```

### Default Values

```bash
error_exit "Error message"  # Uses ERR_GENERAL and non-recoverable
```

## Cleanup Registration

### Register Cleanup Function

```bash
# Define cleanup function
cleanup_temp_files() {
    rm -rf /tmp/myapp_$$
}

# Register cleanup
register_cleanup "cleanup_temp_files"

# Execute all registered cleanup functions
execute_cleanup
```

### With Arguments

```bash
cleanup_with_args() {
    local path="$1"
    rm -rf "$path"
}

register_cleanup "cleanup_with_args" "/tmp/myapp_$$"
```

## Retry Mechanism

### Basic Retry

```bash
# Retry command up to 3 times with 1s, 2s, 4s delays
retry_command curl -s "https://example.com/file.tar.gz"
```

### Custom Retry Settings

```bash
# Retry up to 5 times, starting with 2s delay
retry_command 5 2 wget "https://example.com/file.tar.gz"
```

### With Timeout

```bash
# Retry with 30s timeout per attempt
retry_command_with_timeout 3 1 30 curl -s "https://example.com/file"
```

## Safe File Operations

### Remove File

```bash
# Safely remove file (checks existence, permissions, path safety)
safe_rm "/tmp/myfile.txt"
```

### Create Directory

```bash
# Safely create directory (recursive, checks permissions)
safe_mkdir "/path/to/dir"
```

### Copy File

```bash
# Safely copy file (checks source, creates destination dir if needed)
safe_cp "/src/file.txt" "/dst/file.txt"
```

### Move File

```bash
# Safely move file (uses copy+delete if direct move fails)
safe_mv "/src/file.txt" "/dst/file.txt"
```

### Write File

```bash
# Safely write to file (creates directory, backs up if exists)
safe_write_file "/etc/myapp/config.conf" "content"
```

## Service Management

### Check Service Status

```bash
# Returns: 0=running, 1=stopped, 2=not installed
service_status "v2ray"
```

### Restart Service

```bash
# Simple restart
service_check_and_restart "v2ray" "restart"

# With specific action
service_check_and_restart "v2ray" "start"
service_check_and_restart "v2ray" "stop"
service_check_and_restart "v2ray" "reload"
```

### Restart with Verification

```bash
# Restart and verify service is running
service_restart_with_retry "v2ray" 3
```

## Context Management

### Create Context

```bash
# Create error handling context for subshells
context_dir=$(create_error_context "myapp")
```

### Destroy Context

```bash
# Clean up context
destroy_error_context "$context_dir"
```

## Utility Functions

### Call Stack

```bash
# Get full call stack
get_call_stack 10

# Get call summary
get_call_summary
```

### Cleanup Registry

```bash
# Show registered cleanup functions
show_cleanup_registry
```

### Self Test

```bash
# Run framework self-test
error_handler_self_test
```

## Error Codes

See [ERROR_CODES.md](../ERROR_CODES.md) for complete error code reference.

## Framework Internals

### Initialization

```bash
init_error_handler
```

Resets global state and registers default cleanup function.

### Global State

- `ERROR_OCCURRED`: Boolean flag for error occurrence
- `CLEANUP_FUNCS`: Array of registered cleanup functions

### Cleanup Flow

1. Register cleanup functions with arguments
2. Execute `execute_cleanup` to run all registered functions
3. Functions run even if some fail (continues execution)
4. Status tracked via `has_error` flag

## Example Script

```bash
#!/bin/bash
set -e

# Source error handler
source src/utils/error_handler.sh

# Initialize
init_error_handler

# Define cleanup function
cleanup() {
    rm -rf /tmp/myapp_$$
}

# Register cleanup
register_cleanup "cleanup"

# Main logic
main() {
    # Safe file operations
    safe_mkdir "/var/log/myapp"
    safe_cp "configTemplate.conf" "/etc/myapp.conf"
    
    # Service management
    if ! service_check_and_restart "v2ray" "restart"; then
        error_exit "Failed to restart V2Ray" $ERR_SERVICE true
    fi
    
    echo "Setup complete!"
}

# Run main function
trap 'execute_cleanup; exit $?' INT TERM
main "$@"
```

## Configuration

No configuration file required. Modify error codes in `error_handler.sh`:

```bash
# Add custom error code
readonly ERR_MY_CUSTOM=12
```

## Testing

Run the built-in self-test:

```bash
source src/utils/error_handler.sh
error_handler_self_test
```
