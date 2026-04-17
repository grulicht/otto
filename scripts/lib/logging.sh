#!/usr/bin/env bash
# OTTO - Structured logging library

OTTO_LOG_LEVEL="${OTTO_LOG_LEVEL:-info}"
OTTO_LOG_FORMAT="${OTTO_LOG_FORMAT:-human}"
OTTO_LOG_FILE="${OTTO_LOG_FILE:-}"

# Log level numeric values
declare -A LOG_LEVELS=( [debug]=0 [info]=1 [warn]=2 [error]=3 )

_should_log() {
    local level="$1"
    local current_level_num="${LOG_LEVELS[${OTTO_LOG_LEVEL}]:-1}"
    local msg_level_num="${LOG_LEVELS[${level}]:-1}"
    [ "${msg_level_num}" -ge "${current_level_num}" ]
}

_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if ! _should_log "${level}"; then
        return 0
    fi

    # Human-readable output to stderr
    local color=""
    case "${level}" in
        debug) color="${DIM:-}" ;;
        info)  color="${BLUE:-}" ;;
        warn)  color="${YELLOW:-}" ;;
        error) color="${RED:-}" ;;
    esac
    echo -e "${color}[${level^^}]${NC:-} ${message}" >&2

    # JSON log to file if configured
    if [ -n "${OTTO_LOG_FILE}" ]; then
        printf '{"ts":"%s","level":"%s","msg":"%s"}\n' \
            "${timestamp}" "${level}" "${message}" >> "${OTTO_LOG_FILE}"
    fi
}

log_debug() { _log debug "$@"; }
log_info()  { _log info "$@"; }
log_warn()  { _log warn "$@"; }
log_error() { _log error "$@"; }
