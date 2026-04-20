#!/usr/bin/env bash
# OTTO - Log rotation for state files
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_LOG_ROTATE_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_LOG_ROTATE_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"

# Default maximum log file size in MB
OTTO_LOG_MAX_SIZE_MB="${OTTO_LOG_MAX_SIZE_MB:-50}"
# Default number of rotated files to keep
OTTO_LOG_KEEP_COUNT="${OTTO_LOG_KEEP_COUNT:-5}"

# --- Public API ---

# Check if a file needs rotation based on size.
# Returns 0 if rotation is needed, 1 otherwise.
# Usage: logrotate_check <file> [max_size_mb]
logrotate_check() {
    local file="$1"
    local max_size_mb="${2:-${OTTO_LOG_MAX_SIZE_MB}}"

    if [[ ! -f "${file}" ]]; then
        return 1
    fi

    local size_bytes
    size_bytes=$(stat -c %s "${file}" 2>/dev/null || stat -f %z "${file}" 2>/dev/null) || {
        log_warn "Cannot determine size of ${file}"
        return 1
    }

    local max_size_bytes=$(( max_size_mb * 1024 * 1024 ))
    if [[ ${size_bytes} -ge ${max_size_bytes} ]]; then
        return 0
    fi

    return 1
}

# Rotate a file: file -> file.1 -> file.2 -> ... -> file.N (oldest deleted).
# Usage: logrotate_rotate <file> [keep_count]
logrotate_rotate() {
    local file="$1"
    local keep_count="${2:-${OTTO_LOG_KEEP_COUNT}}"

    if [[ ! -f "${file}" ]]; then
        log_warn "File not found for rotation: ${file}"
        return 0
    fi

    log_info "Rotating log file: ${file}"

    # Remove the oldest if it exists
    if [[ -f "${file}.${keep_count}" ]]; then
        rm -f "${file}.${keep_count}"
    fi

    # Shift existing rotated files
    local i
    for (( i = keep_count - 1; i >= 1; i-- )); do
        local next=$(( i + 1 ))
        if [[ -f "${file}.${i}" ]]; then
            mv "${file}.${i}" "${file}.${next}"
        fi
    done

    # Rotate the current file
    mv "${file}" "${file}.1"

    # Create a fresh empty file
    touch "${file}"

    log_info "Rotated ${file} (keeping ${keep_count} copies)"
}

# Auto-rotate all log files in the state directory.
# Usage: logrotate_auto
logrotate_auto() {
    local state_dir="${OTTO_HOME}/state"

    if [[ ! -d "${state_dir}" ]]; then
        log_debug "State directory does not exist, nothing to rotate"
        return 0
    fi

    local rotated=0

    # Rotate .jsonl files (structured logs)
    for logfile in "${state_dir}"/*.jsonl "${state_dir}"/*.log; do
        [[ -f "${logfile}" ]] || continue
        if logrotate_check "${logfile}"; then
            logrotate_rotate "${logfile}"
            (( rotated++ ))
        fi
    done

    if [[ ${rotated} -gt 0 ]]; then
        log_info "Auto-rotated ${rotated} log file(s)"
    else
        log_debug "No log files needed rotation"
    fi
}
