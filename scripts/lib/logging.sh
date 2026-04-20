#!/usr/bin/env bash
# OTTO - Structured logging library

OTTO_LOG_LEVEL="${OTTO_LOG_LEVEL:-info}"
OTTO_LOG_FORMAT="${OTTO_LOG_FORMAT:-human}"
OTTO_LOG_FILE="${OTTO_LOG_FILE:-}"

# Log level numeric values - use function instead of associative array
# to avoid issues with `set -u` and bash associative array quirks
_log_level_num() {
    case "${1:-}" in
        debug) echo 0 ;;
        info)  echo 1 ;;
        warn)  echo 2 ;;
        error) echo 3 ;;
        *)     echo 1 ;;
    esac
}

_should_log() {
    local level="${1:-info}"
    local current_level_num
    current_level_num=$(_log_level_num "${OTTO_LOG_LEVEL}")
    local msg_level_num
    msg_level_num=$(_log_level_num "${level}")
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
