#!/usr/bin/env bats
# OTTO - Auto-remediation engine tests

setup() {
    OTTO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    export OTTO_DIR
    export OTTO_HOME="$(mktemp -d)"

    mkdir -p "${OTTO_HOME}/state/night-watch"

    source "${OTTO_DIR}/scripts/lib/logging.sh"

    # Set allowed/forbidden before sourcing (the script reads them at source time)
    export REMEDIATION_ALLOWED_ACTIONS="restart_crashed_pods,clear_disk_space,rotate_logs"
    export REMEDIATION_FORBIDDEN_ACTIONS="drop_database"
    export REMEDIATION_LOG="${OTTO_HOME}/state/night-watch/remediation.jsonl"

    source "${OTTO_DIR}/scripts/core/auto-remediation.sh"
}

teardown() {
    [ -d "${OTTO_HOME}" ] && rm -rf "${OTTO_HOME}"
}

@test "remediation_check_allowed returns 0 for allowed action" {
    run remediation_check_allowed "restart_crashed_pods"
    [ "$status" -eq 0 ]
}

@test "remediation_check_allowed returns 1 for unknown action" {
    run remediation_check_allowed "delete_everything"
    [ "$status" -eq 1 ]
}

@test "remediation_check_allowed returns 1 for forbidden action" {
    run remediation_check_allowed "drop_database"
    [ "$status" -eq 1 ]
}

@test "remediation_log writes entry to JSONL file" {
    run remediation_log "restart_crashed_pods" "ns/pod1" "SUCCESS"
    [ "$status" -eq 0 ]
    [ -f "${REMEDIATION_LOG}" ]

    local count
    count=$(wc -l < "${REMEDIATION_LOG}")
    [ "$count" -eq 1 ]

    # Validate JSON structure
    run jq -e '.action' "${REMEDIATION_LOG}"
    [ "$status" -eq 0 ]
    [ "$output" = '"restart_crashed_pods"' ]
}

@test "remediation_log appends multiple entries" {
    remediation_log "rotate_logs" "system" "STARTED"
    remediation_log "rotate_logs" "system" "SUCCESS"

    local count
    count=$(wc -l < "${REMEDIATION_LOG}")
    [ "$count" -eq 2 ]
}
