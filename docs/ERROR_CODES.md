# Error Codes

## Overview

This document defines all error codes used in V2Ray installation script and error handling framework.

## Error Codes

### Success Codes

| Code | Name | Description |
|------|------|-------------|
| 0 | ERR_SUCCESS | Operation completed successfully |

### General Errors

| Code | Name | Description |
|------|------|-------------|
| 1 | ERR_GENERAL | General error |
| 2 | ERR_INVALID_ARGS | Invalid arguments provided |
| 3 | ERR_PERMISSION_DENIED | Permission denied |
| 4 | ERR_FILE_NOT_FOUND | File or directory not found |

### Network and Dependency Errors

| Code | Name | Description |
|------|------|-------------|
| 5 | ERR_NETWORK | Network-related error |
| 6 | ERR_DEPENDENCY | Missing dependency |

### Configuration and Service Errors

| Code | Name | Description |
|------|------|-------------|
| 7 | ERR_CONFIG | Configuration error |
| 8 | ERR_SERVICE | Service-related error |

### Cleanup and Retry Errors

| Code | Name | Description |
|------|------|-------------|
| 9 | ERR_CLEANUP | Cleanup operation failed |
| 10 | ERR_RETRY_EXHAUSTED | All retry attempts exhausted |
| 11 | ERR_SERVICE_ACTION | Service action failed |

### Additional Error Types

| Code | Name | Description |
|------|------|-------------|
| 12+ | ERR_* | Additional custom error codes |

## Usage Example

```bash
# Source the error handler
source src/utils/error_handler.sh

# Basic error exit with default code
error_exit "File not found" $ERR_FILE_NOT_FOUND false

# Recoverable error (won't exit)
error_exit "Configuration warning" $ERR_CONFIG true

# Using error codes in validation
if [[ -z "$port" ]]; then
    error_exit "Port cannot be empty" $ERR_INVALID_ARGS false
fi
```

## Error Code Reference

### ERR_SUCCESS (0)
Operation completed successfully. No action needed.

### ERR_GENERAL (1)
Generic error. Use when no other specific error code applies.

### ERR_INVALID_ARGS (2)
Function received invalid or missing arguments. Check function parameters.

### ERR_PERMISSION_DENIED (3)
Operation failed due to insufficient permissions. Run with appropriate privileges.

### ERR_FILE_NOT_FOUND (4)
Required file or directory does not exist. Verify file paths.

### ERR_NETWORK (5)
Network operation failed. Check network connectivity.

### ERR_DEPENDENCY (6)
Required dependency is missing. Install required software packages.

### ERR_CONFIG (7)
Configuration error. Check configuration file format and values.

### ERR_SERVICE (8)
Service operation failed. Check service status and logs.

### ERR_CLEANUP (9)
Cleanup operation failed. Some cleanup functions did not execute successfully.

### ERR_RETRY_EXHAUSTED (10)
All retry attempts exhausted. Command failed after maximum retry attempts.

### ERR_SERVICE_ACTION (11)
Service action failed. Check service logs for details.

## Best Practices

1. **Always use defined constants**: Use `ERR_*` constants instead of hardcoded numbers
2. **Provide context**: Include relevant information in error messages
3. **Choose appropriate codes**: Select the most specific error code available
4. **Handle recoverable errors**: Use the third parameter to indicate if error is recoverable
5. **Log errors**: Use `log_error()` to ensure proper logging

## Common Patterns

```bash
# File operations
if [[ ! -f "$config_file" ]]; then
    error_exit "Config file not found: $config_file" $ERR_FILE_NOT_FOUND false
fi

# Network operations
if ! curl -s "https://example.com" >/dev/null; then
    error_exit "Failed to download resource" $ERR_NETWORK false
fi

# Service management
if ! service_check_and_restart "v2ray" "restart"; then
    log_error "Failed to restart V2Ray service"
    exit $ERR_SERVICE
fi
```
