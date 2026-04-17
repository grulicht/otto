#!/usr/bin/env bash
# OTTO - Error handling framework

# Trap handler for unexpected errors
otto_error_trap() {
    local exit_code=$?
    local line_number="${1:-unknown}"
    log_error "Unexpected error (exit code ${exit_code}) at line ${line_number}"
    log_error "Stack trace:"
    local i=0
    while caller "${i}" 2>/dev/null; do
        i=$((i + 1))
    done
    return "${exit_code}"
}

# Setup error trapping for a script
otto_setup_traps() {
    trap 'otto_error_trap ${LINENO}' ERR
}

# Run a command with error handling, returns 0 on success
otto_run() {
    local description="$1"
    shift

    log_debug "Running: ${description}"
    if "$@" 2>&1; then
        log_debug "Success: ${description}"
        return 0
    else
        local exit_code=$?
        log_warn "Failed: ${description} (exit code ${exit_code})"
        return "${exit_code}"
    fi
}

# Run a command, return default value on failure
otto_run_or_default() {
    local default="$1"
    shift

    local output
    if output=$("$@" 2>/dev/null); then
        echo "${output}"
    else
        echo "${default}"
    fi
}

# Check if a command exists
otto_require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "${cmd}" &>/dev/null; then
        log_error "Required command not found: ${cmd}"
        [ -n "${install_hint}" ] && log_error "Install with: ${install_hint}"
        return 1
    fi
    return 0
}
