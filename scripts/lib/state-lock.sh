#!/usr/bin/env bash
# OTTO - File-based state locking using flock
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_STATE_LOCK_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_STATE_LOCK_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"

_LOCK_DIR="${OTTO_HOME}/state/locks"

# --- Public API ---

# Acquire a file lock. Blocks up to timeout seconds.
# Usage: state_lock_acquire <lock_name> [timeout_seconds]
state_lock_acquire() {
    local lock_name="$1"
    local timeout="${2:-30}"

    mkdir -p "${_LOCK_DIR}"
    local lock_file="${_LOCK_DIR}/${lock_name}.lock"

    # Open a file descriptor for the lock file
    exec 200>"${lock_file}"

    if ! flock -w "${timeout}" 200; then
        log_error "Failed to acquire lock '${lock_name}' within ${timeout}s"
        return 1
    fi

    # Write PID for debugging
    echo $$ >&200
    log_debug "Lock '${lock_name}' acquired by PID $$"
}

# Release a file lock.
# Usage: state_lock_release <lock_name>
state_lock_release() {
    local lock_name="$1"
    local lock_file="${_LOCK_DIR}/${lock_name}.lock"

    if [[ ! -f "${lock_file}" ]]; then
        log_warn "Lock file not found: ${lock_name}"
        return 0
    fi

    # Release the lock by closing the file descriptor
    exec 200>&-
    log_debug "Lock '${lock_name}' released by PID $$"
}

# Run a command while holding a lock.
# Usage: state_with_lock <lock_name> <command> [args...]
state_with_lock() {
    local lock_name="$1"
    shift

    state_lock_acquire "${lock_name}" || return 1

    local rc=0
    "$@" || rc=$?

    state_lock_release "${lock_name}"
    return ${rc}
}
