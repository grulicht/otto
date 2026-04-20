#!/usr/bin/env bats
# OTTO - Web server tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    mkdir -p "${OTTO_HOME}/state"

    source "${OTTO_DIR}/scripts/lib/colors.sh"
    source "${OTTO_DIR}/scripts/lib/logging.sh"
    source "${OTTO_DIR}/scripts/lib/json-utils.sh"
    source "${OTTO_DIR}/scripts/lib/error-handling.sh"
    source "${OTTO_DIR}/scripts/core/web-server.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "webserver_status returns not running when no PID file" {
    run webserver_status
    [ "$status" -eq 1 ]
    [[ "$output" == *"not running"* ]]
}

@test "webserver_status returns not running for stale PID file" {
    # Write a PID that does not exist
    echo "999999999" > "${OTTO_HOME}/state/webserver.pid"
    run webserver_status
    [ "$status" -eq 1 ]
    [[ "$output" == *"not running"* ]]
}

@test "webserver_public_status_page generates HTML file" {
    run webserver_public_status_page
    [ "$status" -eq 0 ]

    local html_file="${OTTO_HOME}/state/public-status.html"
    [ -f "${html_file}" ]
    grep -q '<html' "${html_file}"
    grep -q 'System Status' "${html_file}"
}

@test "webserver_public_status_page includes status from state.json" {
    # Set up a state file with known status
    echo '{"status": "healthy", "last_heartbeat": "2025-01-15T08:00:00Z"}' > "${OTTO_HOME}/state/state.json"

    webserver_public_status_page

    local html_file="${OTTO_HOME}/state/public-status.html"
    grep -q 'healthy' "${html_file}"
}
