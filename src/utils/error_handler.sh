#!/bin/bash
# error_handler.sh - Enhanced Error Handling Framework
# Provides unified error handling, retry mechanisms, safe file operations, and cleanup function registration

# Ensure logging functions are available
if ! declare -f log_info >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    . "$(dirname "${BASH_SOURCE[0]}")/../log.sh"
fi

# =============================================================================
# File Name: error_handler.sh
# Description: Enhanced error handling framework providing unified error handling and safe operations
# Author: Developer
# Version: 1.0
# Creation Date: 2026-03-31
# =============================================================================

##
## Unified Error Codes Definition (Extends existing error.sh)
##
# Inherits error code definitions from src/error.sh
# ERR_SUCCESS=0
# ERR_GENERAL=1
# ERR_INVALID_ARGS=2
# ERR_PERMISSION_DENIED=3
# ERR_FILE_NOT_FOUND=4
# ERR_NETWORK=5
# ERR_DEPENDENCY=6
# ERR_CONFIG=7
# ERR_SERVICE=8

# New error codes
readonly ERR_CLEANUP=9
readonly ERR_RETRY_EXHAUSTED=10
readonly ERR_SERVICE_ACTION=11

# =============================================================================
# Global State Variables
# =============================================================================

# Error occurrence flag
ERROR_OCCURRED=false

# Cleanup function registry (array)
CLEANUP_FUNCS=()

# =============================================================================
# Basic Utility Functions
# =============================================================================

##
## Get call stack information
## @param: [max_frames] Maximum number of frames to display (optional, default 10)
## @return: Call stack string
##
get_call_stack() {
    local max_frames="${1:-10}"
    local stack=""
    local i

    for ((i=1; i<max_frames && i<${#BASH_SOURCE[@]}; i++)); do
        local line="${BASH_LINENO[$((i-1))]}"
        local source="${BASH_SOURCE[$i]}"
        local func="${FUNCNAME[$i]}"

        # Only skip get_call_stack itself, don't exclude main (main script)
        if [[ -n "$func" && "$func" != "get_call_stack" ]]; then
            stack+="  at $func($source:$line)\n"
        fi
    done

    echo -e "$stack"
}

##
## Get call stack summary
## @return: Call stack summary string
##
get_call_summary() {
    local summary=""
    local i

    for ((i=1; i<${#BASH_SOURCE[@]} && i<10; i++)); do
        local func="${FUNCNAME[$i]}"
        local line="${BASH_LINENO[$((i-1))]}"
        local source="${BASH_SOURCE[$i]#*src/}"

        # Exclude get_call_stack and get_call_summary themselves
        if [[ -n "$func" && "$func" != "get_call_stack" && "$func" != "get_call_summary" ]]; then
            summary+="${func}:${source}:${line}"
            if [[ $i -lt ${#BASH_SOURCE[@]}-1 ]]; then
                summary+=" <- "
            fi
        fi
    done

    echo "$summary"
}

# =============================================================================
## Cleanup Function Registration Mechanism
# =============================================================================

##
## Register a cleanup function
## @param: cleanup_func Cleanup function name
## @param: ... Arguments to add with the cleanup function (optional)
## @return: 0 Success
## @see: execute_cleanup
##
register_cleanup() {
    local func_name="$1"
    shift

    if [[ -z "$func_name" ]]; then
        log_error "register_cleanup: Cleanup function name cannot be empty"
        return $ERR_INVALID_ARGS
    fi

    # Check if function exists
    if ! declare -f "$func_name" >/dev/null 2>&1; then
        log_error "register_cleanup: Cleanup function '$func_name' is not defined"
        return $ERR_GENERAL
    fi

    # Register cleanup function and its arguments
    CLEANUP_FUNCS+=("$(printf '%q' "$func_name")")
    for arg in "$@"; do
        CLEANUP_FUNCS+=("$(printf '%q' "$arg")")
    done
    CLEANUP_FUNCS+=("__SEP__")  # Separator

    log_debug "Registered cleanup function: $func_name"
    return 0
}

##
## Execute all registered cleanup functions
## @return: 0 Success (even if some cleanup functions fail)
##
execute_cleanup() {
    local has_error=false
    local i=0

    log_info "Executing cleanup functions..."

    while [[ $i -lt ${#CLEANUP_FUNCS[@]} ]]; do
        local func_name="${CLEANUP_FUNCS[$i]}"

        if [[ "$func_name" == "__SEP__" ]]; then
            ((i++))
            continue
        fi

        # Collect arguments
        local args=()
        ((i++))
        while [[ $i -lt ${#CLEANUP_FUNCS[@]} && "${CLEANUP_FUNCS[$i]}" != "__SEP__" ]]; do
            args+=("${CLEANUP_FUNCS[$i]}")
            ((i++))
        done

        # Execute cleanup function
        if [[ -n "$func_name" && ${#args[@]} -gt 0 ]]; then
            if ! "$func_name" "${args[@]}" 2>/dev/null; then
                log_warn "Cleanup function '$func_name' failed to execute"
                has_error=true
            fi
        fi

        # Move past __SEP__
        ((i++))
    done

    # Clear cleanup function list
    CLEANUP_FUNCS=()

    if [[ "$has_error" == "true" ]]; then
        log_error "Some cleanup functions failed to execute"
        return $ERR_CLEANUP
    fi

    log_info "Cleanup functions executed successfully"
    return 0
}

# =============================================================================
# Enhanced Error Handling
# =============================================================================

##
## Enhanced error exit function with stack trace and cleanup
## Provides recoverable error handling, call stack tracing, and cleanup execution
##
## @param: message Error message
## @param: [code] Error code (optional, default ERR_GENERAL)
## @param: [recoverable] Whether this is a recoverable error (optional, default false)
## @return: If recoverable=true, returns error code; otherwise exits script
## @see: register_cleanup execute_cleanup
##
error_exit() {
    local message="$1"
    local code="${2:-$ERR_GENERAL}"
    local recoverable="${3:-false}"

    # Set error flag
    ERROR_OCCURRED=true

    # Log detailed error information
    log_error "========================================"
    log_error "Error Details: $message"
    log_error "Error Code: $code"
    log_error "Call Stack Summary: $(get_call_summary)"
    log_error "Call Stack: $(get_call_stack 15)"
    log_error "========================================"

    # Execute cleanup functions
    if [[ ${#CLEANUP_FUNCS[@]} -gt 0 ]]; then
        execute_cleanup
    fi

    # Decide whether to exit based on error type
    if [[ "$recoverable" == "true" ]]; then
        log_warn "Recoverable error, continuing execution..."
        return $code
    else
        log_error "Non-recoverable error, exiting..."
        exit $code
    fi
}

# =============================================================================
# Retry Mechanism
# =============================================================================

##
## Command execution with retry mechanism (exponential backoff)
## Automatically retries failed commands, up to 3 times by default, using exponential backoff strategy
##
## @param: max_attempts Maximum retry attempts (optional, default 3)
## @param: delay Initial delay in seconds (optional, default 1)
## @param: ... Command and its arguments
## @return: 0 Success, otherwise returns failure code
## @exit: If retry exhausted, calls error_exit
## @see: error_exit
##
retry_command() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    shift 2

    # Check if command is specified
    if [[ $# -eq 0 ]]; then
        log_error "retry_command: No command specified"
        error_exit "retry_command: No command specified" $ERR_INVALID_ARGS false
    fi

    local cmd=("$@")
    local attempt=0

    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        log_info "Executing command [$attempt/$max_attempts]: ${cmd[*]}"

        # Execute command
        if "${cmd[@]}"; then
            if [[ $attempt -gt 1 ]]; then
                log_info "Command successful, retry count: $((attempt-1))"
            fi
            return 0
        fi

        # Check if there are retry attempts left
        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "Command failed, retrying after ${delay}s (attempt $attempt)"
            # Use awk for floating-point arithmetic
            sleep "$delay"
            # Exponential backoff: 1, 2, 4, 8, ...
            delay=$(awk "BEGIN {printf \"%.1f\", $delay * 2}")
        fi
    done

    # Retry exhausted
    log_error "Command retry failed [$((attempt-1))/$max_attempts]: ${cmd[*]}"
    error_exit "Command retry failed: ${cmd[*]}" $ERR_RETRY_EXHAUSTED false
}

##
## Command execution with retry and timeout
## Adds timeout control on top of retry_command
##
## @param: max_attempts Maximum retry attempts (optional, default 3)
## @param: delay Initial delay in seconds (optional, default 1)
## @param: timeout Single command timeout in seconds (optional, default 60)
## @param: ... Command and its arguments
## @return: 0 Success, otherwise returns failure code
##
retry_command_with_timeout() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    local timeout="${3:-60}"
    shift 3

    # Wrap command with timeout
    local wrapped_cmd=("timeout" "$timeout" "${@}")

    retry_command "$max_attempts" "$delay" "${wrapped_cmd[@]}"
}

# =============================================================================
# Safe File Operation Wrappers
# =============================================================================

##
## Safely remove file/directory
## Checks file existence, permissions, and path safety
##
## @param: file File or directory path
## @param: ... Additional arguments passed to rm
## @return: 0 Success
## @see: error_exit
##
safe_rm() {
    local path="$1"
    shift

    if [[ -z "$path" ]]; then
        log_error "safe_rm: Path cannot be empty"
        error_exit "safe_rm: Path cannot be empty" $ERR_INVALID_ARGS false
    fi

    # Check if path is empty
    if [[ "$path" == "" ]]; then
        log_error "safe_rm: Cannot remove empty path"
        error_exit "safe_rm: Cannot remove empty path" $ERR_INVALID_ARGS false
    fi

    # Check if path is root directory
    if [[ "$path" == "/" ]]; then
        log_error "safe_rm: Cannot remove root directory"
        error_exit "safe_rm: Cannot remove root directory" $ERR_GENERAL false
    fi

    # Check if path contains dangerous patterns (configurable)
    if [[ "$path" == *".."* ]] && [[ "$path" != *"/../*" && "$path" != "../"* ]]; then
        # Check if it's .. in relative path
        if [[ "$path" == *"../"* ]] || [[ "$path" == *".." ]]; then
            log_warn "safe_rm: Path contains '..', performing safety check: $path"
        fi
    fi

    # Check if file exists
    if [[ ! -e "$path" ]]; then
        log_info "safe_rm: File does not exist, skipping deletion: $path"
        return 0
    fi

    # Log deletion operation
    log_info "safe_rm: Deleting file/directory: $path"
    if [[ -d "$path" ]]; then
        log_debug "safe_rm: This is a directory"
    elif [[ -f "$path" ]]; then
        log_debug "safe_rm: This is a file"
    fi

    # Execute deletion
    if rm -rf "$path" "$@"; then
        log_info "safe_rm: Deletion successful: $path"
        return 0
    else
        log_error "safe_rm: Deletion failed: $path"
        error_exit "safe_rm: Deletion failed: $path" $ERR_GENERAL true
    fi
}

##
## Safely create directory
## Checks permissions, recursive creation, and existence
##
## @param: dir Directory path
## @param: ... Additional arguments passed to mkdir
## @return: 0 Success
## @see: error_exit
##
safe_mkdir() {
    local dir="$1"
    shift

    if [[ -z "$dir" ]]; then
        log_error "safe_mkdir: Path cannot be empty"
        error_exit "safe_mkdir: Path cannot be empty" $ERR_INVALID_ARGS false
    fi

    # Check if directory already exists
    if [[ -d "$dir" ]]; then
        log_info "safe_mkdir: Directory already exists: $dir"
        return 0
    fi

    # Check if parent directory exists
    local parent_dir
    parent_dir="$(dirname "$dir")"
    if [[ ! -d "$parent_dir" ]]; then
        log_info "safe_mkdir: Parent directory does not exist, creating: $parent_dir"
        safe_mkdir "$parent_dir"
    fi

    # Log creation operation
    log_info "safe_mkdir: Creating directory: $dir"

    # Execute creation
    if mkdir -p "$dir" "$@"; then
        log_info "safe_mkdir: Creation successful: $dir"
        return 0
    else
        log_error "safe_mkdir: Creation failed: $dir"
        error_exit "safe_mkdir: Creation failed: $dir" $ERR_GENERAL true
    fi
}

##
## Safely copy file/directory
## Checks source file existence and destination directory permissions
##
## @param: src Source path
## @param: dst Destination path
## @param: ... Additional arguments passed to cp
## @return: 0 Success
## @see: error_exit
##
safe_cp() {
    local src="$1"
    local dst="$2"
    shift 2

    if [[ -z "$src" ]]; then
        log_error "safe_cp: Source path cannot be empty"
        error_exit "safe_cp: Source path cannot be empty" $ERR_INVALID_ARGS false
    fi

    if [[ -z "$dst" ]]; then
        log_error "safe_cp: Destination path cannot be empty"
        error_exit "safe_cp: Destination path cannot be empty" $ERR_INVALID_ARGS false
    fi

    # Check if source file exists
    if [[ ! -e "$src" ]]; then
        log_error "safe_cp: Source file/directory does not exist: $src"
        error_exit "safe_cp: Source file/directory does not exist: $src" $ERR_FILE_NOT_FOUND false
    fi

    # Ensure destination directory exists
    local dst_dir
    dst_dir="$(dirname "$dst")"
    if [[ ! -d "$dst_dir" ]]; then
        log_info "safe_cp: Destination directory does not exist, creating: $dst_dir"
        safe_mkdir "$dst_dir"
    fi

    # Log copy operation
    log_info "safe_cp: Copying: $src -> $dst"
    if [[ -d "$src" ]]; then
        log_debug "safe_cp: This is directory copy"
    fi

    # Execute copy
    if cp -rf "$src" "$dst" "$@"; then
        log_info "safe_cp: Copy successful: $src -> $dst"
        return 0
    else
        log_error "safe_cp: Copy failed: $src -> $dst"
        error_exit "safe_cp: Copy failed: $src -> $dst" $ERR_GENERAL true
    fi
}

##
## Safely move file/directory
## Combines safe copy and safe delete
##
## @param: src Source path
## @param: dst Destination path
## @param: ... Additional arguments passed to mv
## @return: 0 Success
## @see: safe_cp safe_rm
##
safe_mv() {
    local src="$1"
    local dst="$2"
    shift 2

    # Try direct move first
    if mv -f "$src" "$dst" "$@" 2>/dev/null; then
        log_info "safe_mv: Move successful: $src -> $dst"
        return 0
    fi

    # Move failed, use copy + delete
    log_info "safe_mv: Direct move failed, using copy + delete: $src -> $dst"
    safe_cp "$src" "$dst"
    safe_rm "$src"
    return 0
}

##
## Safely write to file
## Ensures directory exists, backs up original file if exists
##
## @param: file File path
## @param: content File content
## @param: [backup] Whether to backup original file (optional, default true)
## @return: 0 Success
## @see: safe_mkdir
##
safe_write_file() {
    local file="$1"
    local content="$2"
    local backup="${3:-true}"

    if [[ -z "$file" ]]; then
        log_error "safe_write_file: File path cannot be empty"
        error_exit "safe_write_file: File path cannot be empty" $ERR_INVALID_ARGS false
    fi

    # Ensure directory exists
    local dir
    dir="$(dirname "$file")"
    safe_mkdir "$dir"

    # Backup original file
    if [[ -f "$file" && "$backup" == "true" ]]; then
        local backup_file="${file}.bak.$(date +%Y%m%d%H%M%S)"
        log_info "safe_write_file: Backing up original file: $file -> $backup_file"
        safe_cp "$file" "$backup_file"
    fi

    # Write file
    if echo -n "$content" > "$file"; then
        log_info "safe_write_file: Write successful: $file"
        return 0
    else
        log_error "safe_write_file: Write failed: $file"
        error_exit "safe_write_file: Write failed: $file" $ERR_GENERAL true
    fi
}

# =============================================================================
# Service Status Check and Operations
# =============================================================================

##
## Check service status
## @param: service Service name
## @return: 0 Running, 1 Stopped, 2 Not installed
##
service_status() {
    local service="$1"

    # Check if service exists
    if ! systemctl list-unit-files "$service" 2>/dev/null | grep -q "$service"; then
        # Try alternative check method
        if [[ ! -f "/lib/systemd/system/$service" ]] && [[ ! -f "/etc/systemd/system/$service" ]]; then
            return 2
        fi
    fi

    # Check if service is running
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        return 0
    fi

    # Check if process exists
    if pidof "$service" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

##
## Check service status and take appropriate action
## Automatically handles service start/stop/reload
##
## @param: service Service name
## @param: action Operation: start|stop|restart|reload
## @param: [timeout] Timeout in seconds (optional, default 30)
## @return: 0 Success
## @see: error_exit
##
service_check_and_restart() {
    local service="$1"
    local action="${2:-restart}"
    local timeout="${3:-30}"

    if [[ -z "$service" ]]; then
        log_error "service_check_and_restart: Service name cannot be empty"
        error_exit "service_check_and_restart: Service name cannot be empty" $ERR_INVALID_ARGS false
    fi

    log_info "service_check_and_restart: Processing service '$service', action: $action"

    # Check if systemctl is available
    if ! command -v systemctl &>/dev/null; then
        log_warn "systemctl not available, trying service command"
        # Use service command
        case "$action" in
            start)
                service "$service" start
                ;;
            stop)
                service "$service" stop
                ;;
            restart)
                service "$service" restart
                ;;
            reload)
                service "$service" reload
                ;;
            *)
                log_error "Unknown action: $action"
                error_exit "service_check_and_restart: Unknown action: $action" $ERR_GENERAL false
                ;;
        esac
        return $?
    fi

    # Check if service file exists
    local unit_file="/lib/systemd/system/${service}.service"
    if [[ ! -f "$unit_file" ]]; then
        unit_file="/etc/systemd/system/${service}.service"
    fi

    if [[ ! -f "$unit_file" ]]; then
        log_error "Service file does not exist: $unit_file"
        error_exit "Service file does not exist: $unit_file" $ERR_SERVICE false
    fi

    # Execute action based on current status
    case "$action" in
        start)
            if service_status "$service" == 0; then
                log_info "Service '$service' is already running"
                return 0
            fi
            log_info "Starting service: $service"
            if systemctl start "$service" 2>&1 | while IFS= read -r line; do
                log_debug "systemctl: $line"
            done; then
                log_info "Service started successfully: $service"
                return 0
            else
                log_error "Service failed to start: $service"
                error_exit "Service failed to start: $service" $ERR_SERVICE false
            fi
            ;;

        stop)
            if service_status "$service" == 1 || service_status "$service" == 2; then
                log_info "Service '$service' is already stopped"
                return 0
            fi
            log_info "Stopping service: $service"
            if systemctl stop "$service" 2>&1 | while IFS= read -r line; do
                log_debug "systemctl: $line"
            done; then
                log_info "Service stopped successfully: $service"
                return 0
            else
                log_error "Service failed to stop: $service"
                error_exit "Service failed to stop: $service" $ERR_SERVICE false
            fi
            ;;

        restart)
            log_info "Restarting service: $service"
            if systemctl restart "$service" 2>&1 | while IFS= read -r line; do
                log_debug "systemctl: $line"
            done; then
                log_info "Service restarted successfully: $service"
                return 0
            else
                log_error "Service failed to restart: $service"
                error_exit "Service failed to restart: $service" $ERR_SERVICE false
            fi
            ;;

        reload)
            log_info "Reloading service: $service"
            if systemctl reload "$service" 2>&1 | while IFS= read -r line; do
                log_debug "systemctl: $line"
            done; then
                log_info "Service reloaded successfully: $service"
                return 0
            else
                log_error "Service failed to reload: $service"
                error_exit "Service failed to reload: $service" $ERR_SERVICE false
            fi
            ;;

        *)
            log_error "Unknown action: $action"
            error_exit "service_check_and_restart: Unknown action: $action" $ERR_GENERAL false
            ;;
    esac
}

##
## Restart service and verify (with retry)
##
## @param: service Service name
## @param: max_attempts Retry attempts (optional, default 3)
## @return: 0 Success
## @see: service_check_and_restart retry_command
##
service_restart_with_retry() {
    local service="$1"
    local max_attempts="${2:-3}"

    service_check_and_restart "$service" restart

    # Verify service is running
    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        if service_status "$service" == 0; then
            log_info "Service verification successful: $service"
            return 0
        fi
        log_warn "Service verification failed, waiting... (attempt $attempt/$max_attempts)"
        sleep 2
    done

    log_error "Service verification failed repeatedly: $service"
    error_exit "Service verification failed repeatedly: $service" $ERR_SERVICE false
}

# =============================================================================
# Context Management
# =============================================================================

##
## Create error handling context (for subshells)
## Creates temporary files for error handling status传递
##
## @param: context_name Context name
## @return: 0 Success
##
create_error_context() {
    local context_name="$1"

    if [[ -z "$context_name" ]]; then
        error_exit "create_error_context: Context name cannot be empty" $ERR_INVALID_ARGS false
    fi

    # Create context directory
    local context_dir="/tmp/v2ray_error_context/${context_name}"
    safe_mkdir "$context_dir"

    # Initialize status file
    echo "false" > "$context_dir/error_occurred"
    echo "$$" > "$context_dir/pid"

    log_debug "Created error handling context: $context_name"
    echo "$context_dir"
}

##
## Destroy error handling context
##
## @param: context_dir Context directory path
## @return: 0 Success
##
destroy_error_context() {
    local context_dir="$1"

    if [[ -z "$context_dir" ]]; then
        error_exit "destroy_error_context: Context directory cannot be empty" $ERR_INVALID_ARGS false
    fi

    safe_rm "$context_dir"
}

# =============================================================================
# Statistics and Diagnostics
# =============================================================================

##
## Display current cleanup function list
##
show_cleanup_registry() {
    if [[ ${#CLEANUP_FUNCS[@]} -eq 0 ]]; then
        echo "No cleanup functions registered"
        return 0
    fi

    echo "=== Registered Cleanup Functions ==="
    local i=0
    while [[ $i -lt ${#CLEANUP_FUNCS[@]} ]]; do
        local func_name="${CLEANUP_FUNCS[$i]}"
        if [[ "$func_name" == "__SEP__" ]]; then
            ((i++))
            continue
        fi
        echo "  - $func_name"
        ((i++))
        # Print arguments
        while [[ $i -lt ${#CLEANUP_FUNCS[@]} && "${CLEANUP_FUNCS[$i]}" != "__SEP__" ]]; do
            echo "      -> ${CLEANUP_FUNCS[$i]}"
            ((i++))
        done
        ((i++))  # Skip __SEP__
    done
    echo "======================================"
}

# =============================================================================
# Testing and Verification
# =============================================================================

##
## Run error handling framework self-test
##
error_handler_self_test() {
    echo "=== Error Handling Framework Self-Test ==="

    # Test 1: Error code definitions
    echo "Test 1: Error Code Definitions"
    if [[ -n "$ERR_CLEANUP" ]]; then
        echo "  ✓ ERR_CLEANUP = $ERR_CLEANUP"
    else
        echo "  ✗ ERR_CLEANUP not defined"
        return 1
    fi

    # Test 2: get_call_stack
    echo "Test 2: Call Stack Tracing"
    local stack
    stack=$(get_call_stack 5)
    if [[ -n "$stack" ]]; then
        echo "  ✓ Call stack retrieval successful"
    else
        echo "  ✗ Call stack retrieval failed"
        return 1
    fi

    # Test 3: Safe directory creation
    echo "Test 3: Safe Directory Creation"
    local test_dir="/tmp/test_error_handler_$$"
    safe_mkdir "$test_dir"
    if [[ -d "$test_dir" ]]; then
        echo "  ✓ Directory creation successful"
        safe_rm "$test_dir"
    else
        echo "  ✗ Directory creation failed"
        return 1
    fi

    # Test 4: Cleanup function registration
    echo "Test 4: Cleanup Function Registration"
    local test_file="/tmp/test_cleanup_$$"
    touch "$test_file"

    _test_cleanup_func() {
        rm -f "$test_file"
    }

    register_cleanup "_test_cleanup_func"
    if [[ ${#CLEANUP_FUNCS[@]} -gt 0 ]]; then
        echo "  ✓ Cleanup function registration successful"
    else
        echo "  ✗ Cleanup function registration failed"
        return 1
    fi

    execute_cleanup
    if [[ ! -f "$test_file" ]]; then
        echo "  ✓ Cleanup function execution successful"
    else
        echo "  ✗ Cleanup function execution failed"
        return 1
    fi

    echo "========================================"
    echo "All tests passed!"
    return 0
}

##
## Initialize error handling framework
## Call at the beginning of script
##
init_error_handler() {
    log_info "Initializing error handling framework..."

    # Reset global state
    ERROR_OCCURRED=false
    CLEANUP_FUNCS=()

    # Register default cleanup function
    register_cleanup "execute_cleanup"

    log_info "Error handling framework initialized"
}
