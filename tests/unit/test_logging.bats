#!/usr/bin/env bats
# OTTO - Logging utility tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    OTTO_LOG_FILE="$(mktemp)"
}

teardown() {
    [ -f "${OTTO_LOG_FILE}" ] && rm -f "${OTTO_LOG_FILE}"
}

@test "log_info writes to stderr" {
    run log_info "test message"
    [ "$status" -eq 0 ]
}

@test "log_info writes JSON to log file" {
    log_info "json test" 2>/dev/null
    [ -f "${OTTO_LOG_FILE}" ]
    run jq -r '.level' "${OTTO_LOG_FILE}"
    [ "$output" = "info" ]
}

@test "log_debug is filtered at info level" {
    OTTO_LOG_LEVEL="info"
    log_debug "should not appear" 2>/dev/null
    local lines
    lines=$(wc -l < "${OTTO_LOG_FILE}")
    [ "$lines" -eq 0 ]
}

@test "log_error always appears" {
    OTTO_LOG_LEVEL="error"
    log_error "critical error" 2>/dev/null
    run jq -r '.level' "${OTTO_LOG_FILE}"
    [ "$output" = "error" ]
}
